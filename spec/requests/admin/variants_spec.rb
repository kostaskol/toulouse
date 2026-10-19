require "rails_helper"

RSpec.describe "Tenant admin product variants", type: :request do
  let(:tenant) { create(:tenant) }
  let(:headers) { staff_cookie(create(:staff_session, tenant:)) }
  let(:product) { as_tenant(tenant) { create(:product, :published) } }
  let(:variant) { product.variants.first }

  it "adds a variant with its selectable values" do
    name = variant.specifications.keys.first
    post "/admin/products/#{product.id}/variants",
         params: attributes_for(:product_variant).slice(:price_cents, :vat_class)
                                                 .merge(specifications: { name => ["#{name} new"] }),
         headers:, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("variant", "selection")).to eq(name => "#{name} new")
  end

  it "refuses a variant that repeats another's selectable values" do
    post "/admin/products/#{product.id}/variants",
         params: attributes_for(:product_variant).slice(:price_cents, :vat_class)
                                                 .merge(specifications: variant.specifications),
         headers:, as: :json

    expect(response.parsed_body["errors"])
      .to contain_exactly(include("code" => "duplicate_combination", "field" => "specifications"))
  end

  it "overrides the product's spec" do
    patch "/admin/products/#{product.id}/variants/#{variant.id}",
          params: { specifications: { "Υλικό" => ["Λινό"] } }, headers:, as: :json

    expect(response.parsed_body.dig("variant", "specifications")).to contain_exactly(include("values" => ["Λινό"]))
  end

  it "refuses a price past the column's limit" do
    patch "/admin/products/#{product.id}/variants/#{variant.id}",
          params: { price_cents: Product::Variant::MAX_INTEGER + 1 }, headers:, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"])
      .to include(include("code" => "less_than_or_equal_to", "field" => "price_cents"))
  end

  it "refuses to archive the last active variant of a published product" do
    patch "/admin/products/#{product.id}/variants/#{variant.id}", params: { status: "archived" }, headers:, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"])
      .to contain_exactly(include("code" => "last_active_variant", "field" => "status"))
  end

  it "archives a variant while another stays active" do
    as_tenant(tenant) { create(:product_variant, product:) }
    patch "/admin/products/#{product.id}/variants/#{variant.id}", params: { status: "archived" }, headers:, as: :json

    expect(response.parsed_body.dig("variant", "status")).to eq("archived")
  end

  it "answers not found for a variant of another product" do
    other = as_tenant(tenant) { create(:product) }
    patch "/admin/products/#{other.id}/variants/#{variant.id}", params: { status: "archived" }, headers:, as: :json

    expect_failure(ApplicationController::FAILURES.fetch(:not_found))
  end
end
