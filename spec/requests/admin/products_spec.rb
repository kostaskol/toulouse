require "rails_helper"

RSpec.describe "Tenant admin products", type: :request do
  let(:tenant) { create(:tenant) }
  let(:staff) { create(:staff, tenant:) }
  let(:headers) { staff_cookie(create(:staff_session, tenant:, staff:)) }
  let(:variant) { attributes_for(:product_variant).slice(:price_cents, :vat_class) }

  def find_product(id) = as_tenant(tenant) { Product.find(id) }

  describe "POST /admin/products" do
    def create_product(**body)
      params = { title: attributes_for(:product)[:title], variants: [variant], **body }
      post "/admin/products", params:, headers:, as: :json
    end

    it "creates a draft product with its variants" do
      create_product

      expect(response).to have_http_status(:created)
      product = response.parsed_body["product"]
      expect(product).to include("status" => "draft", "option_names" => [])
      expect(product["variants"]).to contain_exactly(include("price_cents" => variant[:price_cents]))
    end

    it "takes options and a value per variant" do
      option = attributes_for(:product)[:option_names].first
      create_product(option_names: [option], variants: [variant.merge(option_values: { option => "1" }),
                                                        variant.merge(option_values: { option => "2" })])

      expect(response.parsed_body.dig("product", "variants").pluck("option_values"))
        .to eq([{ option => "1" }, { option => "2" }])
    end

    it "answers one error per invalid field" do
      create_product(title: "", variants: [variant.merge(price_cents: -1)])

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].map { |error| error.slice("code", "field") }).to contain_exactly(
        { "code" => "blank", "field" => "title" },
        { "code" => "greater_than_or_equal_to", "field" => "variants[0].price_cents" }
      )
    end

    it "needs a variant" do
      create_product(variants: [])

      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "blank", "field" => "variants"))
    end

    it "records who made the change" do
      create_product

      version = as_tenant(tenant) { Version.find_by!(item_id: response.parsed_body.dig("product", "id")) }
      expect(version.whodunnit).to eq(staff.to_global_id.to_s)
    end
  end

  describe "GET /admin/products" do
    let!(:products) { as_tenant(tenant) { create_list(:product, 3) } }

    it "lists products newest first, one page at a time" do
      get "/admin/products", params: { limit: 2 }, headers: headers
      first_page = response.parsed_body
      get "/admin/products", params: { limit: 2, after: first_page.dig("meta", "next_cursor") }, headers: headers

      expect(first_page["products"].pluck("id")).to eq(products.reverse.first(2).map(&:id))
      expect(response.parsed_body["products"].pluck("id")).to eq([products.first.id])
      expect(response.parsed_body.dig("meta", "next_cursor")).to be_nil
    end

    it "refuses a cursor that is not an id" do
      get "/admin/products", params: { after: "page-2" }, headers: headers

      expect_failure(Paginates::FAILURES.fetch(:invalid_cursor))
    end

    it "filters by status" do
      as_tenant(tenant) { products.first.update!(status: "published") }
      get "/admin/products", params: { status: "published" }, headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([products.first.id])
    end

    it "filters by brand" do
      brand = as_tenant(tenant) { create(:brand).tap { |brand| products.last.update!(brand:) } }
      get "/admin/products", params: { brand_id: brand.id }, headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([products.last.id])
    end

    it "leaves out other tenants' products" do
      create(:product)
      get "/admin/products", headers: headers

      expect(response.parsed_body["products"].size).to eq(products.size)
    end

    it "searches every status, within the other filters" do
      as_tenant(tenant) { products.first.update!(status: "archived") }
      get "/admin/products", params: { q: products.first.title, status: "archived" }, headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([products.first.id])
      expect(response.parsed_body["meta"]).to eq("next_cursor" => nil, "match" => "exact")
    end

    it "finds a product by the SKU of an archived variant" do
      as_tenant(tenant) do
        create(:product_variant, product: products.first).update!(sku: products.first.id, status: "archived")
      end
      get "/admin/products", params: { q: products.first.id }, headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([products.first.id])
    end

    it "lists every product when the query is blank" do
      get "/admin/products", params: { q: " " }, headers: headers

      expect(response.parsed_body["products"].size).to eq(products.size)
    end

    it "refuses a q sent as an array" do
      get "/admin/products", params: { q: ["π"] }, headers: headers

      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "blank", "field" => "q"))
    end

    it "refuses a query that is too short" do
      get "/admin/products", params: { q: "π" }, headers: headers

      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "query_too_short", "field" => "q"))
    end
  end

  describe "GET /admin/products/:id" do
    it "answers not found for another tenant's product" do
      get "/admin/products/#{create(:product).id}", headers: headers

      expect_failure(ApplicationController::FAILURES.fetch(:not_found))
    end
  end

  describe "PATCH /admin/products/:id" do
    let(:product) { as_tenant(tenant) { create(:product) } }

    it "publishes the product" do
      patch "/admin/products/#{product.id}", params: { status: "published" }, headers:, as: :json

      expect(response).to have_http_status(:ok)
      expect(find_product(product.id)).to be_published
    end

    it "keeps the slug when the title changes" do
      patch "/admin/products/#{product.id}", params: { title: attributes_for(:product)[:title] }, headers:, as: :json

      expect(find_product(product.id).slug).to eq(product.slug)
    end
  end

  describe "PUT /admin/products/:id/options" do
    let(:product) { as_tenant(tenant) { create(:product) } }

    it "renames an option" do
      option = product.option_names.first
      put "/admin/products/#{product.id}/options", params: { option_names: [{ name: "#{option} 2", from: option }] },
                                                   headers:, as: :json

      expect(response.parsed_body.dig("product", "variants", 0, "option_values").keys).to eq(["#{option} 2"])
    end

    [{}, { option_names: ["Option"] }].each do |body|
      it "refuses #{body.inspect} rather than removing every option" do
        put "/admin/products/#{product.id}/options", params: body, headers: headers, as: :json

        expect(response.parsed_body["errors"])
          .to contain_exactly(include("code" => "invalid", "field" => "option_names"))
        expect(find_product(product.id).option_names).to eq(product.option_names)
      end
    end
  end
end
