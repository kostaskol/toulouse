require "rails_helper"

RSpec.describe "Tenant admin product variants", type: :request do
  let(:tenant) { create(:tenant) }
  let(:headers) { staff_cookie(create(:staff_session, tenant:)) }
  let(:product) { as_tenant(tenant) { create(:product, :published) } }
  let(:variant) { product.variants.first }

  it "adds a variant" do
    values = product.option_names.index_with { |name| "#{name} new" }
    post "/admin/products/#{product.id}/variants",
         params: attributes_for(:product_variant).slice(:price_cents, :vat_class).merge(option_values: values),
         headers:, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("variant", "option_values")).to eq(values)
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

  it "points a variant at one of its product's images" do
    image = as_tenant(tenant) { create(:product_image, product:) }
    patch "/admin/products/#{product.id}/variants/#{variant.id}", params: { image_id: image.id }, headers:, as: :json

    expect(response.parsed_body.dig("variant", "image_id")).to eq(image.id)
  end

  it "refuses an image of another product" do
    image = as_tenant(tenant) { create(:product_image) }
    patch "/admin/products/#{product.id}/variants/#{variant.id}", params: { image_id: image.id }, headers:, as: :json

    expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "invalid", "field" => "image_id"))
  end

  it "answers not found for a variant of another product" do
    other = as_tenant(tenant) { create(:product) }
    patch "/admin/products/#{other.id}/variants/#{variant.id}", params: { status: "archived" }, headers:, as: :json

    expect_failure(ApplicationController::FAILURES.fetch(:not_found))
  end
end
