require "rails_helper"

RSpec.describe "Storefront cart", type: :request do
  let(:tenant) { create(:tenant) }
  let(:api_key) { create(:tenant_api_key, tenant:) }
  let(:variant) do
    as_tenant(tenant) { create(:product, :published).variants.first.tap { |v| v.update!(stock_quantity: 3) } }
  end

  def header = V1::Storefront::BaseController::CART_TOKEN_HEADER
  def product = variant.product

  def headers(token: nil, session: nil)
    result = { Tenancy::RequiresTenant::HEADER => api_key.token }
    result[header] = token if token
    result["Authorization"] = "Bearer #{session.token}" if session
    result
  end

  def add(quantity: 1, variant_id: variant.id, **options)
    post "/v1/storefront/cart/lines", params: { variant_id:, quantity: }, headers: headers(**options), as: :json
  end

  def cart_body = response.parsed_body["cart"]
  def cart_count = as_tenant(tenant) { Cart.count }

  # @return [String] the token of a new guest cart holding the variant
  def guest_cart(quantity: 1)
    add(quantity:)
    response.headers[header]
  end

  describe "GET /v1/storefront/cart" do
    it "answers an empty cart and creates none" do
      get "/v1/storefront/cart", headers: headers

      expect(cart_body).to eq("lines" => [], "subtotal_cents" => 0, "line_count" => 0)
      expect(response.headers[header]).to be_nil
      expect(cart_count).to eq(0)
    end

    it "shows the guest cart its token opens" do
      token = guest_cart
      get "/v1/storefront/cart", headers: headers(token:)

      expect(cart_body["lines"].pluck("variant_id")).to eq([variant.id])
    end

    it "shows nothing for another tenant's token" do
      token = guest_cart
      other = create(:tenant_api_key, tenant: create(:tenant))
      get "/v1/storefront/cart", headers: { Tenancy::RequiresTenant::HEADER => other.token, header => token }

      expect(cart_body["lines"]).to eq([])
    end

    it "flags a line over the stock left and counts only what can be bought" do
      token = guest_cart(quantity: 3)
      as_tenant(tenant) { variant.update!(stock_quantity: 1) }
      get "/v1/storefront/cart", headers: headers(token:)

      line = cart_body["lines"].sole
      expect(line.slice("state", "available_quantity", "total_cents"))
        .to eq("state" => "over_stock", "available_quantity" => 1, "total_cents" => variant.price_cents * 3)
      expect(cart_body["subtotal_cents"]).to eq(variant.price_cents)
    end

    it "keeps a line the shopper can no longer buy, outside the subtotal" do
      token = guest_cart
      as_tenant(tenant) { product.update!(status: "archived") }
      get "/v1/storefront/cart", headers: headers(token:)

      expect(cart_body["lines"].sole["state"]).to eq("unavailable")
      expect(cart_body["subtotal_cents"]).to eq(0)
    end
  end

  describe "POST /v1/storefront/cart/lines" do
    it "creates a guest cart and hands its token to the BFF" do
      freeze_time do
        add

        expect(response.headers[header]).to start_with(Cart::TOKEN_PREFIX)
        expect(response.headers[V1::Storefront::BaseController::CART_EXPIRES_HEADER])
          .to eq(Cart::GUEST_IDLE_TIMEOUT.from_now.httpdate)
      end
    end

    def expected_line
      {
        "variant_id" => variant.id,
        "product" => { "title" => product.title, "slug" => product.slug },
        "selection" => as_tenant(tenant) { variant.selection },
        "image" => nil,
        "price_cents" => variant.price_cents,
        "pre_discount_price_cents" => nil,
        "quantity" => 1,
        "total_cents" => variant.price_cents,
        "state" => "buyable"
      }
    end

    it "shows the line as a cart page draws it" do
      add

      expect(cart_body["lines"].sole).to eq(expected_line)
      expect(cart_body.slice("subtotal_cents", "line_count")).to eq("subtotal_cents" => variant.price_cents,
                                                                    "line_count" => 1)
    end

    it "adds to the line of the same variant" do
      token = guest_cart
      add(token:)

      expect(cart_body["lines"].sole["quantity"]).to eq(2)
      expect(response.headers[header]).to eq(token)
    end

    it "lowers the quantity to the stock left and warns" do
      add(quantity: variant.stock_quantity + 1)

      expect(cart_body["lines"].sole["quantity"]).to eq(variant.stock_quantity)
      expect(response.parsed_body["warnings"]).to eq(
        [V1::Storefront::CartLinesController::QUANTITY_REDUCED.to_h.stringify_keys]
      )
    end

    it "refuses a variant that cannot be bought, and creates no cart" do
      as_tenant(tenant) { variant.update!(stock_quantity: 0) }
      add

      expect_failure(V1::Storefront::CartLinesController::FAILURES.fetch(:variant_unavailable))
      expect(cart_count).to eq(0)
    end

    it "refuses a quantity under one" do
      add(quantity: 0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].sole["code"]).to eq("invalid_quantity")
    end

    it "keeps a signed-in shopper's cart on the shopper, whatever cart token comes along" do
      session = create(:shopper_session, tenant:)
      token = guest_cart
      add(token:, session:)

      expect(response.headers[header]).to be_nil
      expect(as_tenant(tenant) { Cart.find_by(shopper: session.shopper).lines.sole.quantity }).to eq(1)
    end
  end

  describe "PUT /v1/storefront/cart/lines/:variant_id" do
    def set(quantity, token)
      put "/v1/storefront/cart/lines/#{variant.id}", params: { quantity: }, headers: headers(token:), as: :json
    end

    it "sets the quantity" do
      token = guest_cart(quantity: 2)
      set(1, token)

      expect(cart_body["lines"].sole["quantity"]).to eq(1)
    end

    it "refuses zero, which is a delete" do
      token = guest_cart
      set(0, token)

      expect(response.parsed_body["errors"].sole["code"]).to eq("invalid_quantity")
    end

    it "answers not found for a variant not in the cart" do
      set(1, nil)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /v1/storefront/cart/lines/:variant_id" do
    it "removes the line" do
      token = guest_cart
      delete "/v1/storefront/cart/lines/#{variant.id}", headers: headers(token:)

      expect(cart_body["lines"]).to eq([])
    end

    it "answers not found for a variant not in the cart" do
      delete "/v1/storefront/cart/lines/#{variant.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "signing in with a guest cart" do
    let(:password) { SecureRandom.alphanumeric(16) }
    let(:shopper) { create(:shopper, tenant:, password:) }

    def log_in(token)
      post "/v1/storefront/session", params: { email: shopper.email, password: }, headers: headers(token:), as: :json
    end

    it "merges the guest cart into the shopper's and warns when both held lines" do
      as_tenant(tenant) { create(:cart, shopper:).add!(variant, 1) }
      log_in(guest_cart)

      expect(response.parsed_body["warnings"]).to eq(
        [V1::Storefront::BaseController::CARTS_MERGED.to_h.stringify_keys]
      )
      expect(as_tenant(tenant) { Cart.find_by(shopper:).lines.sole.quantity }).to eq(2)
    end

    it "gives the shopper the guest cart without a warning when theirs was empty" do
      log_in(guest_cart)

      expect(response.parsed_body).not_to have_key("warnings")
      expect(as_tenant(tenant) { Cart.find_by(shopper:).lines.count }).to eq(1)
    end
  end
end
