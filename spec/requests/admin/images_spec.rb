require "rails_helper"

RSpec.describe "Tenant admin product images", type: :request do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:headers) { staff_cookie(create(:staff_session, tenant:)) }
  let(:product) { as_tenant(tenant) { create(:product) } }

  def upload(bytes = image_bytes, content_type: "image/jpeg")
    post "/admin/products/#{product.id}/images", params: bytes, headers: headers.merge("CONTENT_TYPE" => content_type)
  end

  def image_ids = as_tenant(tenant) { product.images.reload.map(&:id) }

  describe "POST /admin/products/:product_id/images" do
    it "stores the image and answers its sizes" do
      upload(image_bytes(width: 2, height: 1))

      image = response.parsed_body["image"]
      expect(image).to include("alt" => product.title, "width" => 2, "height" => 1)
      expect(image["sizes"].pluck("width")).to eq(Product::Image::WIDTHS)
      expect([image["url"], *image["sizes"].pluck("url")])
        .to all(start_with("#{Rails.configuration.x.media_origin}/media/"))
    end

    # Run after the request, so the jobs see no tenant, as in Solid Queue.
    it "makes every size in the background" do
      upload
      perform_enqueued_jobs

      blob = as_tenant(tenant) { product.images.first.file.blob }
      expect(blob.variant_records.count).to eq(Product::Image::WIDTHS.size + 1)
    end

    it "refuses a body that is not an image type" do
      post "/admin/products/#{product.id}/images", params: {}, headers:, as: :json

      expect_failure(Admin::ImagesController::FAILURES.fetch(:unsupported_media_type))
    end

    it "answers one error for bytes that are not an image" do
      upload(image_bytes("gif"))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "content_type", "field" => "file"))
    end

    it "keeps no image when storage fails" do
      allow(ActiveStorage::Blob.service).to receive(:upload).and_raise(Errno::ECONNRESET)

      expect { upload }.to raise_error(Errno::ECONNRESET)
      expect(image_ids).to be_empty
    end

    it "refuses a body over the size cap" do
      stub_const("Product::Image::MAX_BYTES", image_bytes.bytesize - 1)
      upload

      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "too_large", "field" => "file"))
    end

    it "answers not found for another tenant's product" do
      other = create(:product)
      post "/admin/products/#{other.id}/images", params: image_bytes,
                                                 headers: headers.merge("CONTENT_TYPE" => "image/jpeg")

      expect_failure(ApplicationController::FAILURES.fetch(:not_found))
    end
  end

  describe "PATCH /admin/products/:product_id/images/:id" do
    let(:image) { as_tenant(tenant) { create(:product_image, product:) } }

    it "sets the alt text" do
      patch "/admin/products/#{product.id}/images/#{image.id}", params: { alt: product.title.reverse }, headers:,
                                                                 as: :json

      expect(response.parsed_body.dig("image", "alt")).to eq(product.title.reverse)
    end

    it "falls back to the product title when cleared" do
      as_tenant(tenant) { image.update!(alt: product.title.reverse) }
      patch "/admin/products/#{product.id}/images/#{image.id}", params: { alt: " " }, headers:, as: :json

      expect(response.parsed_body.dig("image", "alt")).to eq(product.title)
    end
  end

  describe "DELETE /admin/products/:product_id/images/:id" do
    let(:image) { as_tenant(tenant) { create(:product_image, product:) } }
    let(:variant) { as_tenant(tenant) { product.variants.first.tap { |variant| variant.update!(image:) } } }

    it "removes the image, purges its file and unlinks its variants" do
      variant
      blob = as_tenant(tenant) { image.file.blob }
      delete "/admin/products/#{product.id}/images/#{image.id}", headers: headers
      perform_enqueued_jobs

      expect([image_ids, ActiveStorage::Blob.exists?(blob.id)]).to eq([[], false])
      expect(as_tenant(tenant) { variant.reload.image_id }).to be_nil
    end
  end

  describe "PUT /admin/products/:product_id/images/order" do
    let!(:images) { as_tenant(tenant) { create_list(:product_image, 3, product:) } }

    def order(ids) = put "/admin/products/#{product.id}/images/order", params: { image_ids: ids }, headers:, as: :json

    it "sets the display order" do
      order(images.map(&:id).reverse)

      expect(response.parsed_body["images"].pluck("id")).to eq(images.map(&:id).reverse)
      expect(image_ids).to eq(images.map(&:id).reverse)
    end

    it "refuses a list that is not every image once" do
      order(images.map(&:id).first(2) + [images.first.id])

      expect(response.parsed_body["errors"]).to contain_exactly(include("code" => "invalid", "field" => "image_ids"))
      expect(image_ids).to eq(images.map(&:id))
    end
  end

  it "includes images in the product, in display order" do
    images = as_tenant(tenant) { create_list(:product_image, 2, product:) }
    get "/admin/products/#{product.id}", headers: headers

    expect(response.parsed_body.dig("product", "images").pluck("id")).to eq(images.map(&:id))
  end
end
