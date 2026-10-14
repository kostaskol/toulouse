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

  describe "filters and facets" do
    it "narrows the result and counts facets over the whole match" do
      brand = as_tenant(tenant) { create(:brand) }
      branded = as_tenant(tenant) { create(:product, :published, title: "Παπούτσια", brand:) }
      as_tenant(tenant) { create(:product, :published, title: "Παπούτσια") }
      search("παπούτσια", filter: { brands: [brand.slug] })

      expect(response.parsed_body["products"].pluck("id")).to eq([branded.id])
      expect(response.parsed_body["facets"]).to include("brands" => [brand.slice(:name, :slug).merge("count" => 1)])
      expect(response.parsed_body["facets"]["price"]).to include("min", "max", "ranges")
    end

    it "filters and counts by facet specs as attributes" do
      as_tenant(tenant) do
        create(:specification, name: "Υλικό", facet: true)
        create(:product, :published, title: "Παπούτσια", specifications: { "Υλικό" => ["Δέρμα"] })
        create(:product, :published, title: "Παπούτσια", specifications: { "Υλικό" => ["Ύφασμα"] })
      end
      search("παπούτσια", filter: { attributes: { "υλικο" => ["δερμα"] } })

      expect(response.parsed_body["products"].size).to eq(1)
      group = response.parsed_body["facets"]["attributes"].find { |facet| facet["key"] == "υλικο" }
      expect(group["values"].pluck("label", "count")).to eq([["Δέρμα", 1], ["Ύφασμα", 1]])
    end

    it "counts facets for a query that holds a question mark" do
      product = as_tenant(tenant) { create(:product, :published) }
      as_tenant(tenant) { product.variants.first.update!(sku: "#{product.slug}?") }
      search(product.variants.first.sku)

      expect(response.parsed_body["facets"]["price"]["min"]).to eq(product.variants.first.price_cents)
    end

    it "leaves facets off a later page" do
      as_tenant(tenant) { create_list(:product, 2, :published, title: "Παπούτσια") }
      search("παπούτσια", limit: 1)
      search("παπούτσια", limit: 1, after: response.parsed_body.dig("meta", "next_cursor"))

      expect(response.parsed_body.keys).to eq(["products", "meta"])
    end

    it "stays exact when a filter empties the result" do
      as_tenant(tenant) { create(:product, :published, title: "Παπούτσια") }
      search("παπούτσια", filter: { brands: [SecureRandom.hex(4)] })

      expect(response.parsed_body["products"]).to be_empty
      expect(response.parsed_body.dig("meta", "match")).to eq("exact")
    end

    it "searches products rather than answering with a category when filtered" do
      as_tenant(tenant) { create(:category, name: "Παπούτσια") }
      search("παπούτσια", filter: { available: "true" })

      expect(response.parsed_body).to include("products" => [])
    end

    it "refuses a malformed filter" do
      search("παπούτσια", filter: "all")

      expect(response.parsed_body["errors"]).to eq([{
        "code" => "invalid_filter", "field" => "filter", "message" => V1::Storefront::FiltersProducts::FAILURE.message
      }])
    end
  end

  describe "category redirect" do
    let!(:category) { as_tenant(tenant) { create(:category, name: "Παπούτσια") } }

    it "answers with the category whose name means the query" do
      search("παπούτσι")

      expect(response.parsed_body).to eq("category" => category.slice(:id, :name, :slug).as_json)
    end

    it "answers with the category whose name the query spells in greeklish" do
      search("papoutsia")

      expect(response.parsed_body["category"]).to eq(category.slice(:id, :name, :slug).as_json)
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
