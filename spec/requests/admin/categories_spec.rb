require "rails_helper"

RSpec.describe "Tenant admin categories", type: :request do
  let(:tenant) { create(:tenant) }
  let(:headers) { staff_cookie(create(:staff_session, tenant:)) }
  let(:root) { as_tenant(tenant) { create(:category) } }

  it "creates a category under a parent" do
    post "/admin/categories", params: { name: "Πουκάμισα", parent_id: root.id }, headers: headers, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["category"]).to include("slug" => "poukamisa", "parent_id" => root.id)
  end

  it "lists the tree with siblings in position order" do
    later, earlier = as_tenant(tenant) { [2, 1].map { |position| create(:category, parent: root, position:) } }
    get "/admin/categories", headers: headers

    expect(response.parsed_body["categories"]).to match([include("id" => root.id, "children" => [
      include("id" => earlier.id, "children" => []), include("id" => later.id, "children" => [])
    ])])
  end

  it "refuses a move under a category below it" do
    child = as_tenant(tenant) { create(:category, parent: root) }
    patch "/admin/categories/#{root.id}", params: { parent_id: child.id }, headers: headers, as: :json

    expect(response.parsed_body["errors"])
      .to contain_exactly(include("code" => "invalid_parent", "field" => "parent_id"))
  end

  it "refuses to remove a category with categories below it" do
    as_tenant(tenant) { create(:category, parent: root) }
    delete "/admin/categories/#{root.id}", headers: headers

    expect_failure(Admin::CategoriesController::FAILURES.fetch(:category_has_children))
  end

  it "refuses to remove a category with products in it" do
    as_tenant(tenant) { create(:product, category: root) }
    delete "/admin/categories/#{root.id}", headers: headers

    expect_failure(Admin::CategoriesController::FAILURES.fetch(:category_has_products))
  end

  it "removes a category with none below it" do
    delete "/admin/categories/#{root.id}", headers: headers

    expect(response).to have_http_status(:no_content)
  end

  describe "specification links" do
    let(:size) { as_tenant(tenant) { create(:specification) } }

    it "sets the links and lists them with the category" do
      links = [{ specification_id: size.id, required: true }]
      patch "/admin/categories/#{root.id}", params: { specification_links: links }, headers: headers, as: :json
      get "/admin/categories", headers: headers

      expect(response.parsed_body.dig("categories", 0, "specification_links"))
        .to eq([{ "specification_id" => size.id, "required" => true }])
    end

    it "refuses an unknown spec" do
      links = [{ specification_id: root.id }]
      patch "/admin/categories/#{root.id}", params: { specification_links: links }, headers: headers, as: :json

      expect(response.parsed_body["errors"])
        .to contain_exactly(include("code" => "invalid", "field" => "specification_links"))
    end

    it "names what a product misses for publishing" do
      as_tenant(tenant) { root.update!(specification_links: [{ specification_id: size.id, required: true }]) }
      product = as_tenant(tenant) { create(:product, category: root) }
      patch "/admin/products/#{product.id}", params: { status: "published" }, headers: headers, as: :json

      expect(response.parsed_body["errors"])
        .to contain_exactly(include("code" => "required_specifications_missing", "field" => "status"))
      get "/admin/products/#{product.id}", headers: headers
      expect(response.parsed_body.dig("product", "missing_specifications")).to eq([size.name])
    end
  end

  describe "product assignment" do
    let(:product) { as_tenant(tenant) { create(:product) } }

    def assign(id) = patch("/admin/products/#{product.id}", params: { category_id: id }, headers: headers, as: :json)

    it "moves the product to the category" do
      assign(root.id)

      expect(response.parsed_body.dig("product", "category_id")).to eq(root.id)
    end

    it "refuses a category of another tenant" do
      assign(create(:category).id)

      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "invalid", "field" => "category_id"))
    end

    it "refuses to leave the product without a category" do
      assign(nil)

      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "blank", "field" => "category_id"))
    end

    it "filters the product list by the product's own category" do
      child = as_tenant(tenant) { create(:category, parent: root) }
      as_tenant(tenant) { create(:product, category: child) }
      assign(root.id)
      get "/admin/products", params: { category_id: root.id }, headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([product.id])
    end
  end
end
