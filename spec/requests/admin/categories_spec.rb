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

  it "removes a category with none below it" do
    delete "/admin/categories/#{root.id}", headers: headers

    expect(response).to have_http_status(:no_content)
  end

  describe "product assignment" do
    let(:product) { as_tenant(tenant) { create(:product) } }

    def assign(ids) = patch("/admin/products/#{product.id}", params: { category_ids: ids }, headers: headers, as: :json)

    it "replaces the product's categories" do
      other = as_tenant(tenant) { create(:category) }
      assign([root.id])
      assign([other.id])

      expect(response.parsed_body.dig("product", "category_ids")).to eq([other.id])
    end

    it "records the removal of a link" do
      assign([root.id])
      assign([])

      events = as_tenant(tenant) { Version.where(item_type: Product::Categorization.name).pluck(:event) }
      expect(events).to eq(["create", "destroy"])
    end

    it "links a category sent twice once" do
      assign([root.id, root.id.upcase])

      expect(response.parsed_body.dig("product", "category_ids")).to eq([root.id])
    end

    it "refuses a category of another tenant" do
      assign([create(:category).id])

      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "invalid", "field" => "category_ids"))
    end

    it "filters the product list by a direct link" do
      child = as_tenant(tenant) { create(:category, parent: root) }
      as_tenant(tenant) { create(:product, category_ids: [child.id]) }
      assign([root.id])
      get "/admin/products", params: { category_id: root.id }, headers: headers

      expect(response.parsed_body["products"].pluck("id")).to eq([product.id])
    end
  end
end
