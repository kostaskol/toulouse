require "rails_helper"

RSpec.describe "Storefront categories", type: :request do
  let(:tenant) { create(:tenant) }
  let(:headers) { { Tenancy::RequiresTenant::HEADER => create(:tenant_api_key, tenant:).token } }
  let(:root) { as_tenant(tenant) { create(:category) } }
  let(:child) { as_tenant(tenant) { create(:category, parent: root) } }

  it "lists the tree" do
    child
    get "/v1/storefront/categories", headers: headers

    expect(response.parsed_body["categories"]).to eq([
      root.slice(:id, :name, :slug).merge("children" => [child.slice(:id, :name, :slug).merge("children" => [])])
    ])
  end

  describe "GET /v1/storefront/categories/:slug/products" do
    it "lists published products from the category and every category below it" do
      on_root, on_child = as_tenant(tenant) do
        [create(:product, :published, category: root), create(:product, :published, category: child)]
      end
      as_tenant(tenant) { create(:product, category: root) }
      get "/v1/storefront/categories/#{root.slug}/products", headers: headers

      expect(response.parsed_body["products"].pluck("id", "category_id"))
        .to eq([[on_child.id, child.id], [on_root.id, root.id]])
    end

    it "narrows by filter and counts facets below the category" do
      branded = as_tenant(tenant) { create(:product, :published, brand: create(:brand), category: child) }
      as_tenant(tenant) { create(:product, :published, category: root) }
      get "/v1/storefront/categories/#{root.slug}/products",
          params: { filter: { brands: [branded.brand.slug] }, limit: 1 }, headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([branded.id])
      expect(response.parsed_body["facets"]["categories"].pluck("id")).to eq([child.id])
      expect(response.parsed_body["facets"]["brands"].pluck("count")).to eq([1])
    end

    it "leaves facets off a later page" do
      product = as_tenant(tenant) { create(:product, :published, category: root) }
      get "/v1/storefront/categories/#{root.slug}/products", params: { after: product.id }, headers: headers

      expect(response.parsed_body.keys).to eq(["products", "meta"])
    end

    it "refuses a malformed filter" do
      get "/v1/storefront/categories/#{root.slug}/products", params: { filter: { price_min: "-1" } }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq([{
        "code" => "invalid_filter", "field" => "filter[price_min]",
        "message" => V1::Storefront::FiltersProducts::FAILURE.message
      }])
    end

    it "answers not found for an unknown category" do
      get "/v1/storefront/categories/#{root.slug}-missing/products", headers: headers

      expect_failure(ApplicationController::FAILURES.fetch(:not_found))
    end
  end
end
