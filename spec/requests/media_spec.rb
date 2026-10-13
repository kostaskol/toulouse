require "rails_helper"

RSpec.describe "Public media", type: :request do
  let(:tenant) { create(:tenant) }
  let(:image) { as_tenant(tenant) { create(:product_image) } }

  def media_path(name) = as_tenant(tenant) do
    variant = image.file.variant(name)
    Rails.application.routes.url_helpers.media_path(variant.blob.signed_id, variant.variation.key, variant.filename)
  end

  it "serves a size with no credential, cacheable by anyone" do
    get media_path(:"w#{Product::Image::WIDTHS.first}")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/webp")
    expect(response.headers["Cache-Control"]).to include("public")
  end

  it "answers not found for a tampered signature" do
    get media_path(:original).sub(%r{/media/[^/]+}) { |segment| "#{segment}x" }

    expect(response).to have_http_status(:not_found)
  end
end
