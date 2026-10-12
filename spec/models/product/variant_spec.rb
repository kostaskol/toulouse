require "rails_helper"

RSpec.describe Product::Variant, :as_tenant, type: :model do
  let(:product) { create(:product) }
  let(:variant) { product.variants.first }
  let(:option) { product.option_names.first }

  it "uses the product_variants table" do
    expect(described_class.table_name).to eq("product_variants")
  end

  it "needs a value for each of the product's options" do
    expect(build(:product_variant, product:, option_values: {})).not_to be_valid
  end

  it "refuses an option the product does not have" do
    values = variant.option_values.merge("#{option} extra" => variant.option_values[option])

    expect(build(:product_variant, product:, option_values: values)).not_to be_valid
  end

  it "refuses the option values of another variant" do
    other = build(:product_variant, product:, option_values: variant.option_values)

    expect(other).not_to be_valid
    expect(other.errors.details[:option_values]).to eq([{ error: :duplicate_combination }])
  end

  it "keeps the SKU unique in the tenant" do
    variant.update!(sku: "#{product.slug}-sku")

    expect(build(:product_variant, product: create(:product), sku: variant.sku)).not_to be_valid
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

  it "needs a compare-at price above the price" do
    expect(build(:product_variant, product:, compare_at_price_cents: variant.price_cents)).not_to be_valid
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
