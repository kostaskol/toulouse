require "rails_helper"

RSpec.describe Product::Import, :as_tenant, type: :model do
  it "uses the product_imports table" do
    expect(described_class.table_name).to eq("product_imports")
    expect(Product::Import::Entry.table_name).to eq("product_import_entries")
  end

  it "allows one active import per tenant" do
    create(:product_import)

    expect { create(:product_import) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows a new import once the last one is done" do
    create(:product_import, status: :done)

    expect { create(:product_import) }.not_to raise_error
  end

  it "appends image errors without overwriting" do
    entry = create(:product_import).entries.create!(position: 0, handle: "a", result: :created)
    entry.add_image_error!(code: "image_unreachable")
    entry.add_image_error!(code: "image_address_refused")

    expect(entry.reload.image_errors.pluck("code")).to eq(["image_unreachable", "image_address_refused"])
  end

  describe "#run!" do
    include ActiveJob::TestHelper

    let(:staff) { create(:staff) }
    let(:rows) do
      [
        { "handle" => "first", "title" => "First", "price" => "1", "brand" => "Maker" },
        { "handle" => "second", "title" => "Second", "price" => "1", "pre_discount_price" => "0.5" }
      ]
    end

    def run(dry_run: false, text: import_csv(rows))
      described_class.start!(staff:, text:, dry_run:).tap(&:run!)
    end

    it "writes each product and its entry" do
      import = run

      expect(import.reload).to have_attributes(status: "done", file: nil)
      expect(import.entries.order(:position).pluck(:result)).to eq(["created", "failed"])
      expect(Product.pluck(:slug)).to eq(["first"])
    end

    it "gives the same entries on a dry run and writes nothing" do
      dry = run(dry_run: true).entries.order(:position).pluck(:result, :created_brands)

      expect(Product.count).to eq(0)
      expect(Brand.count).to eq(0)
      expect(run.entries.order(:position).pluck(:result, :created_brands)).to eq(dry)
    end

    it "skips everything with no warnings when the same file runs again" do
      run
      again = run

      expect(again.entries.find_by(handle: "first")).to have_attributes(result: "skipped", warnings: [])
    end

    it "resumes after the last written entry" do
      import = described_class.start!(staff:, text: import_csv(rows), dry_run: false)
      import.entries.create!(position: 0, handle: "first", result: :created)

      import.run!

      expect(import.entries.order(:position).pluck(:handle)).to eq(["first", "second"])
      expect(Product.pluck(:slug)).to be_empty
    end

    it "records the uploader as the author" do
      run

      expect(Product.first.versions.last.whodunnit).to eq(staff.to_global_id.to_s)
    end

    it "fails on an unexpected error and keeps what it wrote" do
      allow(Product::Import::Writer).to receive(:new).and_call_original
      allow(Product::Import::Writer).to receive(:new).with(having_attributes(handle: "second")).and_raise("boom")

      import = run

      expect(import.reload).to have_attributes(status: "failed", file: nil)
      expect(import.error_details.pluck("code")).to eq(["import_failed"])
      expect(import.entries.pluck(:handle)).to eq(["first"])
    end

    it "stops and stays failed when the import is failed under it" do
      import = described_class.start!(staff:, text: import_csv([rows.first, rows.first.merge("handle" => "third")]),
                                      dry_run: false)
      allow(Product::Import::Writer).to receive(:new).and_wrap_original do |original, group|
        original.(group).tap { described_class.where(id: import.id).update_all(status: :failed) }
      end

      import.run!

      expect(import.reload).to be_failed
      expect(Product.pluck(:slug)).to eq(["first"])
    end

    it "leaves an import alone once it has failed" do
      import = described_class.start!(staff:, text: import_csv(rows), dry_run: false)
      described_class.where(id: import.id).update_all(status: :failed)

      import.run!

      expect(import.reload).to be_failed
      expect(import.entries).to be_empty
    end

    it "queues the images of a new product" do
      rows.first["image_urls"] = "https://host/a.jpg|https://host/b.jpg"

      expect { run }.to have_enqueued_job(ProductImageImportJob).once
      expect(described_class.last.images_pending).to eq(2)
    end

    it "summarises results and warnings" do
      run
      rows.first["title"] = "Changed"
      summary = run.summary

      expect(summary).to include(results: { "skipped" => 1, "failed" => 1 }, warnings: { "product_cell_ignored" => 1 })
    end
  end

  describe ".start!" do
    include ActiveJob::TestHelper

    let(:staff) { create(:staff) }
    let(:text) { import_csv([{ "handle" => "first", "title" => "First", "price" => "1" }]) }

    it "fails a stale active import and starts the new one" do
      stale = create(:product_import, status: :running, file: "x", updated_at: 1.day.ago)

      import = described_class.start!(staff:, text:, dry_run: false)

      expect(stale.reload).to have_attributes(status: "failed", file: nil)
      expect(stale.error_details.pluck("code")).to eq(["import_failed"])
      expect(import).to be_queued
    end

    it "still refuses a second import while one is fresh" do
      create(:product_import, status: :running)

      expect { described_class.start!(staff:, text:, dry_run: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "refuses a second import before reading its file" do
      create(:product_import, status: :running)
      allow(Product::Import::Sheet).to receive(:new).and_call_original

      expect { described_class.start!(staff:, text:, dry_run: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      expect(Product::Import::Sheet).not_to have_received(:new)
    end

    it "touches the import after each product" do
      import = described_class.start!(staff:, text: import_csv([
        { "handle" => "first", "title" => "First", "price" => "1" },
        { "handle" => "second", "title" => "Second", "price" => "1" }
      ]), dry_run: false)
      allow(import).to receive(:touch).and_call_original

      import.run!

      expect(import).to have_received(:touch).twice
    end
  end
end
