require "rails_helper"

RSpec.describe Product::Image, :as_tenant do
  let(:product) { create(:product) }

  def upload(bytes)
    file = Tempfile.new(binmode: true).tap { |tempfile| tempfile.write(bytes) && tempfile.rewind }
    product.images.create(file: described_class.attachable(file, product.slug))
  end

  def error_types(image) = image.errors.map { |error| [error.attribute, error.type] }

  it "takes its type and name from the bytes and the product, not the upload" do
    image = upload(image_bytes("png"))

    expect(image.file.blob).to have_attributes(content_type: "image/png", filename: "#{product.slug}.png")
  end

  it "stores the original under the tenant's path" do
    image = upload(image_bytes)

    expect(image.file.key).to start_with("#{image.tenant_id}/")
  end

  it "records width and height as shown, after EXIF rotation" do
    image = upload(image_bytes(width: 2, height: 1, orientation: 6))

    expect(image.file.metadata.slice(:width, :height)).to eq("width" => 1, "height" => 2)
  end

  it "refuses bytes that are not an accepted image" do
    expect(error_types(upload(image_bytes("gif")))).to eq([[:file, :content_type]])
  end

  it "refuses a file over the size cap" do
    stub_const("#{described_class}::MAX_BYTES", image_bytes.bytesize - 1)

    expect(error_types(upload(image_bytes))).to eq([[:file, :too_large]])
  end

  it "refuses an image over the pixel cap from its header alone" do
    side = Math.sqrt(described_class::MAX_PIXELS).ceil + 1

    expect(error_types(upload(jpeg_claiming(width: side, height: side)))).to eq([[:file, :too_many_pixels]])
  end

  it "refuses an image past the per-product cap" do
    stub_const("#{described_class}::MAX_PER_PRODUCT", 1)
    upload(image_bytes)

    expect(error_types(upload(image_bytes))).to eq([[:base, :too_many_images]])
  end

  it "records the upload once in the audit log" do
    expect(upload(image_bytes).versions.pluck(:event)).to eq(["create"])
  end

  it "puts a new image last" do
    first = upload(image_bytes)

    expect(upload(image_bytes).position).to be > first.position
  end

  it "strips metadata from the copies it serves" do
    image = upload(image_bytes(width: 2, height: 1, orientation: 6))
    copy = Vips::Image.new_from_buffer(image.file.variant(:original).processed.download, "")

    expect([copy.get_typeof("exif-data"), copy.width, copy.height]).to eq([0, 1, 2])
  end

  it "resizes each width to WebP without upscaling" do
    width = described_class::WIDTHS.first
    image = upload(image_bytes(width: width * 2, height: width))
    copy, largest = [width, described_class::WIDTHS.last].map do |size|
      Vips::Image.new_from_buffer(image.file.variant(:"w#{size}").processed.download, "")
    end

    expect([copy.get("vips-loader"), copy.width, largest.width]).to eq(["webpload_buffer", width, width * 2])
  end

  describe "selection" do
    let(:variant) { product.variants.first }
    let(:name) { variant.specifications.keys.first }

    def link(selection) = build(:product_image, product:, selection:).tap(&:valid?)

    it "links to a selectable value the product uses" do
      selection = { name => variant.specifications[name].first }

      expect(link(selection).selection).to eq(selection)
    end

    it "shows on every variant once no variant holds its value" do
      selection = { name => variant.specifications[name].first }
      image = create(:product_image, product:, selection:)

      variant.update!(specifications: { name => ["#{selection[name]} renamed"] })

      expect(image.reload.selection).to eq({})
    end

    it "shows on every variant once a variant saved through its product drops the value" do
      selection = { name => variant.specifications[name].first }
      image = create(:product_image, product:, selection:)

      variant.assign_attributes(specifications: { name => ["#{selection[name]} renamed"] },
                                price_cents: variant.price_cents + 1)
      product.save!

      expect(image.reload.selection).to eq({})
    end

    it "keeps its link while a variant holds the value" do
      selection = { name => variant.specifications[name].first }
      image = create(:product_image, product:, selection:)

      create(:product_variant, product:).update!(specifications: { name => ["#{selection[name]} other"] })

      expect(image.reload.selection).to eq(selection)
    end

    it "shows on every variant with no link" do
      expect(link({}).selection).to eq({})
    end

    {
      "a value the product does not use" => ->(name) { { name => "#{name} other" } },
      "a spec that is not selectable" => ->(_) { { "Οθόνη" => "6.1" } },
      "two values" => ->(name) { { name => "6.1", "Οθόνη" => "6.1" } },
      "an unknown spec" => ->(name) { { "#{name} other" => "6.1" } }
    }.each do |case_name, selection|
      it "refuses #{case_name}" do
        product.update!(specifications: { "Οθόνη" => ["6.1"] })

        expect(link(selection.call(name)).errors.details[:selection]).to eq([{ error: :invalid }])
      end
    end
  end
end
