require "rails_helper"

RSpec.describe ProductImageImportJob, :as_tenant do
  include ActiveJob::TestHelper

  let(:product) { create(:product) }
  let(:import) { create(:product_import, images_pending: 2) }
  let(:entry) { import.entries.create!(position: 0, handle: product.slug, result: :created, product:) }

  def download_returns(bytes)
    allow(Product::Image::Download).to receive(:open) do |_url, &block|
      Tempfile.create(binmode: true) do |file|
        file.write(bytes)
        file.rewind
        block.call(file)
      end
    end
  end

  it "runs after jobs of the default priority" do
    expect(described_class.new.priority).to eq(10)
    expect(ProductImportJob.new.priority).to eq(10)
  end

  it "stores one image and queues the next URL" do
    download_returns(image_bytes)

    expect { described_class.perform_now(entry, ["https://host/a.jpg", "https://host/b.jpg"]) }
      .to have_enqueued_job(described_class).with(entry, ["https://host/b.jpg"])
    expect(product.images.count).to eq(1)
    expect(import.reload.images_pending).to eq(1)
  end

  it "records a download error and carries on" do
    allow(Product::Image::Download).to receive(:open)
      .and_raise(Product::Image::Download::Error.new("image_address_refused", "refused"))

    expect { described_class.perform_now(entry, ["https://host/a.jpg", "https://host/b.jpg"]) }
      .to have_enqueued_job(described_class)
    expect(entry.reload.image_errors).to contain_exactly(include("code" => "image_address_refused"))
  end

  it "records the image model's own error" do
    download_returns(image_bytes("gif"))
    described_class.perform_now(entry, ["https://host/a.jpg"])

    expect(entry.reload.image_errors).to contain_exactly(include("code" => "content_type"))
    expect(import.reload.images_pending).to eq(1)
  end

  it "records an unexpected error as image_failed" do
    allow(Product::Image::Download).to receive(:open).and_raise(Errno::ECONNRESET)
    described_class.perform_now(entry, ["https://host/a.jpg"])

    expect(entry.reload.image_errors).to contain_exactly(include("code" => "image_failed"))
  end
end
