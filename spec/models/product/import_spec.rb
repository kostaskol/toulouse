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
end
