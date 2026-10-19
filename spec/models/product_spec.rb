require "rails_helper"

RSpec.describe Product, :as_tenant, type: :model do
  let(:product) { create(:product) }
  let(:colour) { create(:specification, name: "Χρώμα", kind: "colour", multiple: false, selectable: true) }

  # @param own [Hash{String => Array<String>}] the product's own specs
  # @param overrides [Array<Hash{String => Array<String>}>] one per variant
  def build_with(own, *overrides)
    product = build(:product, specifications: own)
    product.variants = overrides.map { |specifications| build(:product_variant, product:, specifications:) }
    product
  end

  it "needs a variant to be created" do
    product = build(:product)
    product.variants = []

    expect(product).not_to be_valid
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

  describe "specifications" do
    def stored(record) = record.class.find(record.id).specifications

    it "replaces the whole set, values in the given order" do
      product.update!(specifications: { "Υλικό" => ["Μετάξι", "Βαμβάκι"], "Χώρα" => ["Ελλάδα"] })
      product.update!(specifications: { "υλικο" => ["Βαμβάκι", "Λινό"] })

      expect(stored(product)).to eq("Υλικό" => ["Βαμβάκι", "Λινό"])
    end

    it "keeps values that stay, so the audit log shows only changes" do
      product.update!(specifications: { "Υλικό" => ["Μετάξι"] })

      expect { product.update!(specifications: { "Υλικό" => ["Μετάξι", "Λινό"] }) }
        .to change { Version.where(item_type: "Product::SpecificationValue").count }.by(1)
    end

    it "lists specs in definition order" do
      product.update!(specifications: { "Υλικό" => ["Μετάξι"], "Χώρα" => ["Ελλάδα"] })
      Specification.find_by!(name: "Χώρα").update!(position: -1)

      expect(stored(product).keys).to eq(["Χώρα", "Υλικό"])
    end

    it "keeps a variant's overrides apart from the product's own" do
      product.update!(specifications: { "Υλικό" => ["Μετάξι"] })
      product.variants.first.update!(specifications: { "Υλικό" => ["Λινό"] })

      expect(stored(product)).to eq("Υλικό" => ["Μετάξι"])
      expect(stored(product.variants.first)).to eq("Υλικό" => ["Λινό"])
    end

    {
      "a list rather than names" => [["Μετάξι"]],
      "a value that is not a list" => { "Υλικό" => "Μετάξι" },
      "an empty list" => { "Υλικό" => [] },
      "a blank value" => { "Υλικό" => [" "] },
      "a blank name" => { " " => ["Μετάξι"] },
      "two names that fold alike" => { "Υλικό" => ["Μετάξι"], "υλικο" => ["Λινό"] }
    }.each do |name, specifications|
      it "refuses #{name}" do
        product.specifications = specifications

        expect(product).not_to be_valid
        expect(product.errors.details[:specifications]).to eq([{ error: :invalid }])
      end
    end
  end

  describe "variant selection" do
    it "refuses two values for a single-value spec" do
      product.specifications = { colour.name => ["Λευκό", "Μαύρο"] }

      expect(product).not_to be_valid
      expect(product.errors.details[:specifications]).to eq([{ error: :single_value }])
    end

    it "refuses two specs of one kind" do
      size = create(:specification, kind: "size", multiple: false, selectable: true)
      other = create(:specification, kind: "size", multiple: false, selectable: true)
      product.specifications = { size.name => ["Λευκό"], other.name => ["Μαύρο"] }

      expect(product).not_to be_valid
      expect(product.errors.details[:specifications]).to eq([{ error: :kind_taken }])
    end

    it "lets variants differ by the values they override" do
      expect(build_with({}, { colour.name => ["Λευκό"] }, { colour.name => ["Μαύρο"] })).to be_valid
    end

    it "refuses a variant with no value for a selectable spec another variant uses" do
      product = build_with({}, { colour.name => ["Λευκό"] }, {})

      expect(product).not_to be_valid
      expect(product.errors.details[:"variants[1].specifications"]).to eq([{ error: :selection_incomplete }])
    end

    it "lets an archived variant go without the value" do
      product = build_with({}, { colour.name => ["Λευκό"] }, {})
      product.variants.last.status = "archived"

      expect(product).to be_valid
    end

    it "refuses a product value that makes two variants repeat each other" do
      product = build_with({ colour.name => ["Μαύρο"] }, { colour.name => ["Λευκό"] }, {})
      product.save!

      expect(product.update(specifications: { colour.name => ["Λευκό"] })).to be(false)
      expect(product.errors.details[:specifications]).to eq([{ error: :duplicate_combination }])
    end

    it "refuses two variants with no selectable spec" do
      product = build_with({}, {}, {})

      expect(product).not_to be_valid
      expect(product.errors.details[:"variants[1].specifications"]).to eq([{ error: :duplicate_combination }])
    end
  end
end
