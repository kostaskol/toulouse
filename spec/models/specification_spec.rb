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
    expect(resolved["Μνήμη"]).to be_persisted.and(
      have_attributes(name: "Μνήμη", facet: false, mode: "any", kind: "none", multiple: true, selectable: false)
    )
  end

  it "matches a name with spaces around it" do
    screen = create(:specification, name: "Οθόνη")

    expect(described_class.resolve([" Οθόνη "])).to eq(" Οθόνη " => screen)
  end

  it "strips itself from every product and variant when deleted" do
    product = create(:product, specifications: { "Οθόνη" => ["6.1"] })
    product.variants.first.update!(specifications: { "Οθόνη" => ["6.7"] })

    removals = -> { Version.where(item_type: "Product::SpecificationValue", event: "destroy").count }

    expect { described_class.find_by!(name: "Οθόνη").destroy! }
      .to have_enqueued_job(ProductSearchRefreshJob).with([product.id]).and change(&removals).by(2)
    expect(Product::SpecificationValue.joins(:specification).where(specification: { name: "Οθόνη" })).to be_empty
  end

  describe "flags" do
    def errors_of(**attributes) = build(:specification, **attributes).tap(&:valid?).errors.details

    it "needs variant selection for a kind" do
      expect(errors_of(kind: "colour", multiple: false)[:selectable]).to eq([{ error: :required_by_kind }])
    end

    it "needs a single value for variant selection" do
      expect(errors_of(selectable: true)[:multiple]).to eq([{ error: :off_when_selectable }])
    end

    it "keeps the all mode to multi-value specs" do
      expect(errors_of(multiple: false, mode: "all")[:mode]).to eq([{ error: :any_when_single }])
    end
  end

  describe "a change existing products would break" do
    let(:product) { create(:product) }
    let(:selectable) { described_class.find_by!(name: product.variants.first.specifications.keys.first) }

    it "refuses a single value while a product holds two" do
      create(:product, specifications: { "Οθόνη" => ["6.1", "OLED"] })

      expect(described_class.find_by!(name: "Οθόνη").update(multiple: false)).to be(false)
    end

    it "refuses to turn variant selection off when variants differ only by it" do
      create(:product_variant, product:)

      expect(selectable.update(selectable: false)).to be(false)
      expect(selectable.errors.details[:selectable]).to eq([{ error: :selection_in_use }])
    end

    it "refuses to turn variant selection on when a variant has no value" do
      create(:product_variant, product:)
      product.variants.first.update!(specifications: product.variants.first.specifications.merge("Οθόνη" => ["6.1"]))
      screen = described_class.find_by!(name: "Οθόνη")

      expect(screen.update(multiple: false, selectable: true)).to be(false)
      expect(screen.errors.details[:selectable]).to eq([{ error: :selection_in_use }])
    end

    it "refuses a kind the product already uses on another spec" do
      selectable.update!(kind: "size")
      product.update!(specifications: { "Οθόνη" => ["6.1"] })
      screen = described_class.find_by!(name: "Οθόνη")

      expect(screen.update(kind: "size", multiple: false, selectable: true)).to be(false)
      expect(screen.errors.details[:kind]).to eq([{ error: :kind_in_use }])
    end

    it "unlinks images when variant selection goes" do
      value = product.variants.first.specifications.values.first.first
      image = create(:product_image, product:, selection: { selectable.name => value })

      selectable.update!(selectable: false, multiple: true)

      expect(image.reload.selection).to eq({})
    end
  end
end
