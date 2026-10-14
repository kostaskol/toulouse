require "rails_helper"

RSpec.describe "Storefront products", type: :request do
  let(:tenant) { create(:tenant) }
  let(:headers) { { Tenancy::RequiresTenant::HEADER => create(:tenant_api_key, tenant:).token } }
  let(:product) { as_tenant(tenant) { create(:product, :published, brand: create(:brand)) } }

  it "lists published products only" do
    as_tenant(tenant) { [create(:product), create(:product, :published).tap { |p| p.update!(status: "archived") }] }
    product
    get "/v1/storefront/products", headers: headers

    expect(response.parsed_body["products"].pluck("id")).to eq([product.id])
  end

  it "shows a published product by slug, with its brand and variants" do
    get "/v1/storefront/products/#{product.slug}", headers: headers

    body = response.parsed_body["product"]
    expect(body["brand"]).to eq(product.brand.slice(:name, :slug))
    expect(body["variants"].pluck("id")).to eq(product.variants.map(&:id))
    expect(body["variants"].first.keys).not_to include("status", "vat_class", "mpn")
  end

  it "shows the product's specs and each variant's overrides" do
    as_tenant(tenant) do
      product.update!(specifications: { "Υλικό" => ["Μετάξι"] })
      product.variants.first.update!(specifications: { "Υλικό" => ["Λινό"] })
    end
    get "/v1/storefront/products/#{product.slug}", headers: headers

    body = response.parsed_body["product"]
    expect(body["specifications"]).to eq([{ "name" => "Υλικό", "values" => ["Μετάξι"] }])
    expect(body["variants"].first["specifications"]).to eq([{ "name" => "Υλικό", "values" => ["Λινό"] }])
  end

  it "shows images in display order, and which one each variant uses" do
    images = as_tenant(tenant) { create_list(:product_image, 2, product:) }
    as_tenant(tenant) { product.variants.first.update!(image: images.last) }
    get "/v1/storefront/products/#{product.slug}", headers: headers

    body = response.parsed_body["product"]
    expect(body["images"].pluck("id")).to eq(images.map(&:id))
    expect(body["variants"].first["image_id"]).to eq(images.last.id)
  end

  it "tells whether each variant can be bought" do
    as_tenant(tenant) { create(:product_variant, product:, track_stock: false) }
    get "/v1/storefront/products/#{product.slug}", headers: headers

    expect(response.parsed_body.dig("product", "variants").pluck("available")).to eq([false, true])
  end

  it "hides archived variants" do
    archived = as_tenant(tenant) do
      create(:product_variant, product:)
      product.variants.first.tap { |variant| variant.update!(status: "archived") }
    end
    get "/v1/storefront/products/#{product.slug}", headers: headers

    expect(response.parsed_body.dig("product", "variants").pluck("id")).not_to include(archived.id)
  end

  it "answers not found for a draft product" do
    product.then { as_tenant(tenant) { product.update!(status: "draft") } }
    get "/v1/storefront/products/#{product.slug}", headers: headers

    expect_failure(ApplicationController::FAILURES.fetch(:not_found))
  end
end
