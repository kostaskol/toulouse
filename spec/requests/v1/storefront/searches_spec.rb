require "rails_helper"

RSpec.describe "Storefront search", type: :request do
  let(:tenant) { create(:tenant) }
  let(:headers) { { Tenancy::RequiresTenant::HEADER => create(:tenant_api_key, tenant:).token } }

  def search(query, **params)
    get "/v1/storefront/search/#{ERB::Util.url_encode(query)}", params:, headers:
  end

  it "finds published products and says the match was exact" do
    product = as_tenant(tenant) { create(:product, :published, title: "Παπούτσια") }
    as_tenant(tenant) { create(:product, title: "Παπούτσια") }
    search("παπούτσια")

    expect(response.parsed_body["products"].pluck("id")).to eq([product.id])
    expect(response.parsed_body["meta"]).to eq("next_cursor" => nil, "match" => "exact")
  end

  it "uses the product list's JSON" do
    product = as_tenant(tenant) { create(:product, :published) }
    search(product.title)
    listed = response.parsed_body["products"]
    get "/v1/storefront/products", headers: headers

    expect(listed).to eq(response.parsed_body["products"])
  end

  it "finds a product by the barcode of an active variant only" do
    product = as_tenant(tenant) { create(:product, :published) }
    archived = as_tenant(tenant) do
      create(:product_variant, product:).tap { |variant| variant.update!(barcode: product.id, status: "archived") }
    end
    search(archived.barcode)

    expect(response.parsed_body["products"]).to be_empty
  end

  it "takes a query with a slash or a dot" do
    product = as_tenant(tenant) { create(:product, :published) }
    as_tenant(tenant) { product.variants.first.update!(sku: "#{product.slug}/#{product.slug}.") }
    search(product.variants.first.sku)

    expect(response.parsed_body["products"].pluck("id")).to eq([product.id])
  end

  describe "category redirect" do
    let!(:category) { as_tenant(tenant) { create(:category, name: "Παπούτσια") } }

    it "answers with the category whose name means the query" do
      search("παπούτσι")

      expect(response.parsed_body).to eq("category" => category.slice(:id, :name, :slug).as_json)
    end

    it "searches products when two categories share the name" do
      as_tenant(tenant) { create(:category, name: category.name, parent: create(:category)) }
      search(category.name)

      expect(response.parsed_body).to include("products" => [])
    end

    it "searches products when the query holds more than the name" do
      search("#{category.name} #{category.slug}")

      expect(response.parsed_body).to include("products")
    end

    it "searches products on a later page" do
      products = as_tenant(tenant) { create_list(:product, 2, :published, category_ids: [category.id]) }
      _page, cursor = as_tenant(tenant) do
        Product::Search.new(category.name, products: Product.all, variants: Product::Variant.all)
                       .page(after: nil, limit: 1)
      end
      search(category.name, limit: 1, after: cursor)

      expect(response.parsed_body["products"].pluck("id")).to eq([products.first.id])
    end
  end

  {
    " " => :blank,
    "\u00A0\u00A0" => :blank,
    "π" => :query_too_short,
    "π" * (Product::Search::MAX_LENGTH + 1) => :query_too_long
  }.each do |query, code|
    it "refuses a query that is #{code}" do
      search(query)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq(
        [{ "code" => code.to_s, "field" => "query", "message" => SearchesProducts::FAILURES.fetch(code).message }]
      )
    end
  end

  it "counts a decomposed accent as part of its letter" do
    search("ά".unicode_normalize(:nfd))

    expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "query_too_short"))
  end

  it "refuses a cursor it did not issue" do
    search("παπούτσια", after: "page-2")

    expect_failure(Paginates::FAILURES.fetch(:invalid_cursor))
  end
end
