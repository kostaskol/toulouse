require "rails_helper"

RSpec.describe "Tenant admin specifications", type: :request do
  let(:tenant) { create(:tenant) }
  let(:headers) { staff_cookie(create(:staff_session, tenant:)) }
  let!(:specification) { as_tenant(tenant) { create(:specification) } }

  it "creates a definition that is no facet and matches any value by default" do
    post "/admin/specifications", params: { name: "Οθόνη" }, headers:, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["specification"])
      .to include("name" => "Οθόνη", "position" => 0, "facet" => false, "mode" => "any")
  end

  it "refuses a name that folds like one the tenant uses" do
    post "/admin/specifications", params: { name: specification.name.upcase }, headers:, as: :json

    expect(response.parsed_body["errors"]).to include(include("code" => "taken", "field" => "name"))
  end

  it "refuses an unknown mode" do
    patch "/admin/specifications/#{specification.id}", params: { mode: "some" }, headers:, as: :json

    expect(response.parsed_body["errors"]).to include(include("code" => "inclusion", "field" => "mode"))
  end

  it "lists definitions in display order" do
    later = as_tenant(tenant) { create(:specification, position: 1) }
    get "/admin/specifications", headers: headers

    expect(response.parsed_body["specifications"].pluck("id")).to eq([specification.id, later.id])
  end

  it "turns a definition into a conjunctive facet" do
    patch "/admin/specifications/#{specification.id}", params: { facet: true, mode: "all" }, headers:, as: :json

    expect(response.parsed_body["specification"]).to include("facet" => true, "mode" => "all")
  end

  it "deletes a definition and strips it from products" do
    product = as_tenant(tenant) { create(:product, specifications: { specification.name => ["1"] }) }
    delete "/admin/specifications/#{specification.id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(as_tenant(tenant) { Product.find(product.id).specifications }).to be_empty
  end
end
