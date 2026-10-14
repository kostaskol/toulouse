require "rails_helper"

RSpec.describe Specification, :as_tenant do
  it "keys a name by its folded form" do
    expect(create(:specification, name: "Οθόνη").key).to eq("οθονη")
  end

  it "refuses a name that folds like another" do
    create(:specification, name: "Οθόνη")

    expect(build(:specification, name: "ΟΘΟΝΗ").tap(&:valid?).errors.details[:name]).to eq([{ error: :taken }])
  end

  it "finds definitions by folded name and creates the missing ones" do
    screen = create(:specification, name: "Οθόνη")

    resolved = described_class.resolve(["οθονη", "Μνήμη"])

    expect(resolved["οθονη"]).to eq(screen)
    expect(resolved["Μνήμη"]).to be_persisted.and(have_attributes(name: "Μνήμη", facet: false, mode: "any"))
  end

  it "matches a name with spaces around it" do
    screen = create(:specification, name: "Οθόνη")

    expect(described_class.resolve([" Οθόνη "])).to eq(" Οθόνη " => screen)
  end

  it "strips itself from every product and variant when deleted" do
    product = create(:product, specifications: { "Οθόνη" => ["6.1"] })
    product.variants.first.update!(specifications: { "Οθόνη" => ["6.7"] })

    expect { described_class.find_by!(name: "Οθόνη").destroy! }
      .to have_enqueued_job(ProductSearchRefreshJob).with([product.id])
    expect(Product::SpecificationValue.count).to eq(0)
    expect(Version.where(item_type: "Product::SpecificationValue", event: "destroy").count).to eq(2)
  end
end
