require "rails_helper"

RSpec.describe Product, :as_tenant, type: :model do
  let(:product) { create(:product) }
  let(:option) { product.option_names.first }

  def add_variant(product, **attributes) = create(:product_variant, product:, **attributes)

  it "needs a variant to be created" do
    product = build(:product)
    product.variants = []

    expect(product).not_to be_valid
  end

  it "accepts up to #{described_class::MAX_OPTIONS} options" do
    names = Array.new(described_class::MAX_OPTIONS + 1) { |index| "#{option} #{index}" }

    expect(build(:product, option_names: names)).not_to be_valid
  end

  it "refuses an option name used twice" do
    expect(build(:product, option_names: [option, option])).not_to be_valid
  end

  it "refuses a brand of another tenant" do
    brand = create(:brand, tenant: create(:tenant))

    product = build(:product, brand_id: brand.id)

    expect(product).not_to be_valid
    expect(product.errors.details[:brand_id]).to eq([{ error: :invalid }])
  end

  it "refuses a malformed brand id rather than clearing the brand" do
    product = build(:product, brand_id: "#{create(:brand).id}x")

    expect(product).not_to be_valid
  end

  describe "publishing" do
    it "is allowed with an active variant" do
      expect(product.update(status: "published")).to be(true)
    end

    it "is refused when every variant is archived" do
      product.variants.first.update!(status: "archived")
      product.reload

      expect(product.update(status: "published")).to be(false)
      expect(product.errors.details[:status]).to eq([{ error: :no_active_variant }])
    end
  end

  describe "#update_options!" do
    before { add_variant(product) }

    it "renames an option on every variant" do
      product.update_options!([{ name: "#{option} renamed", from: option }])

      expect(product.reload.variants.map { |variant| variant.option_values.keys }).to all(eq(["#{option} renamed"]))
    end

    it "adds an option with one value for every variant" do
      product.update_options!([{ name: option, from: option }, { name: "Added", value: "Value" }])

      expect(product.reload.variants.map { |variant| variant.option_values["Added"] }).to eq(["Value", "Value"])
      expect(product.option_names).to eq([option, "Added"])
    end

    it "refuses to remove an option when two variants would match" do
      expect { product.update_options!([]) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(product.reload.option_names).to eq([option])
    end

    it "removes an option when the variants stay distinct" do
      product.update_options!([{ name: option, from: option }, { name: "Added", value: "Value" }])
      product.reload.update_options!([{ name: option, from: option }])

      expect(product.reload.variants.map { |variant| variant.option_values.keys }).to all(eq([option]))
    end

    it "refuses to keep an option the product does not have" do
      expect { product.update_options!([{ name: option, from: "#{option} missing" }]) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it "lets two variants swap option values in one save" do
      first, second = product.reload.variants.to_a
      first.option_values, second.option_values = second.option_values, first.option_values

      expect { product.save! }.not_to raise_error
    end
  end
end
