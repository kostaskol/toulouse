require "rails_helper"

RSpec.describe Product::Variant, :as_tenant, type: :model do
  let(:product) { create(:product) }
  let(:variant) { product.variants.first }

  it "uses the product_variants table" do
    expect(described_class.table_name).to eq("product_variants")
  end

  describe "selection" do
    it "needs a value for each selectable spec its siblings use" do
      other = build(:product_variant, product:, specifications: {})

      expect(other).not_to be_valid
      expect(other.errors.details[:specifications]).to eq([{ error: :selection_incomplete }])
    end

    it "refuses the selectable values of another variant" do
      other = build(:product_variant, product:, specifications: variant.specifications)

      expect(other).not_to be_valid
      expect(other.errors.details[:specifications]).to eq([{ error: :duplicate_combination }])
    end

    it "refuses a value that leaves a sibling without one" do
      create(:product_variant, product:)
      colour = create(:specification, multiple: false, selectable: true)

      expect(variant.update(specifications: variant.specifications.merge(colour.name => ["Λευκό"]))).to be(false)
      expect(variant.errors.details[:specifications]).to eq([{ error: :selection_incomplete }])
    end

    it "refuses a spec of a kind the product already uses" do
      size, other = create_list(:specification, 2, kind: "size", multiple: false, selectable: true)
      product.update!(specifications: { size.name => ["Λευκό"] })

      expect(variant.update(specifications: variant.specifications.merge(other.name => ["Μαύρο"]))).to be(false)
      expect(variant.errors.details[:specifications]).to eq([{ error: :kind_taken }])
    end

    it "is checked again when an archived variant comes back" do
      sibling = create(:product_variant, product:, status: "archived", specifications: {})

      expect(sibling.update(status: "active")).to be(false)
      expect(sibling.errors.details[:specifications]).to eq([{ error: :selection_incomplete }])
    end

    it "lists selectable values by name, an override over the product's value" do
      colour = create(:specification, multiple: false, selectable: true, position: -1)
      product.update!(specifications: { colour.name => ["Λευκό"], "Υλικό" => ["Λινό"] })

      expect(variant.reload.selection.keys).to eq([colour.name, *variant.specifications.keys])
      expect(variant.selection[colour.name]).to eq("Λευκό")
    end
  end

  it "keeps the SKU unique in the tenant" do
    variant.update!(sku: "#{product.slug}-sku")

    expect(build(:product_variant, product: create(:product), sku: variant.sku)).not_to be_valid
  end

  it "refuses the SKU of an unsaved sibling" do
    product = build(:product)
    product.variants.first.sku = "#{product.title}-sku"
    sibling = build(:product_variant, product:, sku: product.variants.first.sku)
    product.variants << sibling

    expect(sibling).not_to be_valid
    expect(sibling.errors.details[:sku]).to eq([{ error: :taken }])
  end

  it "lets two variants go without a SKU" do
    variant.update!(sku: " ")

    expect(create(:product_variant, product:, sku: "").sku).to be_nil
  end

  it "lets another tenant use the same SKU" do
    variant.update!(sku: "#{product.slug}-sku")
    other_tenant = create(:tenant)
    other = as_tenant(other_tenant) { create(:product_variant, tenant: other_tenant, sku: variant.sku) }

    expect(other).to be_persisted
  end

  ["price_cents", "pre_discount_price_cents", "stock_quantity"].each do |column|
    it "refuses a #{column} past the column's limit" do
      variant.assign_attributes(column => described_class::MAX_INTEGER + 1)

      expect(variant).not_to be_valid
      expect(variant.errors.details[column.to_sym]).to include(include(error: :less_than_or_equal_to))
    end
  end

  it "needs a pre-discount price above the price" do
    expect(build(:product_variant, product:, pre_discount_price_cents: variant.price_cents)).not_to be_valid
  end

  it "stops at #{described_class::MAX_PER_PRODUCT} variants on a product" do
    stub_const("#{described_class}::MAX_PER_PRODUCT", 2)
    create(:product_variant, product:)

    expect(build(:product_variant, product: product.reload)).not_to be_valid
  end

  describe "#available?" do
    it "is false for tracked stock at zero" do
      expect(variant).not_to be_available
    end

    it "is true with stock" do
      variant.stock_quantity = 1

      expect(variant).to be_available
    end

    it "is true when stock is not tracked" do
      variant.track_stock = false

      expect(variant).to be_available
    end

    it "is true when oversell is allowed" do
      variant.allow_oversell = true

      expect(variant).to be_available
    end
  end

  describe "archiving" do
    let(:product) { create(:product, :published) }

    it "is refused on the last active variant of a published product" do
      expect(variant.update(status: "archived")).to be(false)
      expect(variant.errors.details[:status]).to eq([{ error: :last_active_variant }])
    end

    it "is allowed while another variant stays active" do
      create(:product_variant, product:)

      expect(product.reload.variants.first.update(status: "archived")).to be(true)
    end

    it "is allowed on a draft product" do
      product.update!(status: "draft")

      expect(variant.update(status: "archived")).to be(true)
    end
  end
end
