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
        [create(:product, :published, category_ids: [root.id]), create(:product, :published, category_ids: [child.id])]
      end
      as_tenant(tenant) { create(:product, category_ids: [root.id]) }
      get "/v1/storefront/categories/#{root.slug}/products", headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([on_child.id, on_root.id])
    end

    it "lists a product linked twice in the subtree once" do
      product = as_tenant(tenant) { create(:product, :published, category_ids: [root.id, child.id]) }
      get "/v1/storefront/categories/#{root.slug}/products", headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([product.id])
    end

    it "answers not found for an unknown category" do
      get "/v1/storefront/categories/#{root.slug}-missing/products", headers: headers

      expect_failure(ApplicationController::FAILURES.fetch(:not_found))
    end
  end
end
