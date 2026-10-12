require "rails_helper"

RSpec.describe "Tenant admin brands", type: :request do
  let(:tenant) { create(:tenant) }
  let(:headers) { staff_cookie(create(:staff_session, tenant:)) }
  let!(:brand) { as_tenant(tenant) { create(:brand) } }

  it "creates a brand with a slug from its name" do
    post "/admin/brands", params: { name: "Πουκάμισο" }, headers:, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["brand"]).to include("name" => "Πουκάμισο", "slug" => "poukamiso")
  end

  it "refuses a name the tenant already uses" do
    post "/admin/brands", params: { name: brand.name }, headers:, as: :json

    expect(response.parsed_body["errors"]).to include(include("code" => "taken", "field" => "name"))
  end

  it "lists brands" do
    get "/admin/brands", headers: headers

    expect(response.parsed_body).to eq("brands" => [brand.slice(:id, :name, :slug)], "meta" => { "next_cursor" => nil })
  end

  it "renames a brand" do
    name = attributes_for(:brand)[:name]
    patch "/admin/brands/#{brand.id}", params: { name: }, headers:, as: :json

    expect(response.parsed_body.dig("brand", "name")).to eq(name)
  end

  it "deletes an unused brand" do
    delete "/admin/brands/#{brand.id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(as_tenant(tenant) { Brand.exists?(brand.id) }).to be(false)
  end

  it "refuses to delete a brand that products use" do
    as_tenant(tenant) { create(:product, brand:) }
    delete "/admin/brands/#{brand.id}", headers: headers

    expect_failure(Admin::BrandsController::FAILURES.fetch(:brand_in_use))
  end
end
