require "rails_helper"

RSpec.describe Product::Import::Group, :as_tenant do
  let(:base) { { "handle" => "first", "title" => "First", "price" => "1" } }

  def group(*rows)
    Product::Import::Sheet.new(import_csv(rows)).groups.first
  end

  def codes(group) = group.errors.map { |error| [error[:code], error[:field]] }

  it "reads both decimal marks as cents" do
    variants = group(base.merge("price" => "12,50"), base.merge("price" => "12.5")).variants

    expect(variants.map { |variant| variant.attributes[:price_cents] }).to eq([1250, 1250])
  end

  it "refuses a price with both marks or three decimals" do
    expect(codes(group(base.merge("price" => "1.250,00")))).to eq([["invalid", "price"]])
    expect(codes(group(base.merge("price" => "1.255")))).to eq([["invalid", "price"]])
  end

  it "needs a price on every row" do
    expect(codes(group(base, base.merge("price" => "")))).to eq([["blank", "price"]])
  end

  it "defaults the status, VAT class and stock" do
    variant = group(base).variants.first

    expect(group(base).product_attributes[:status]).to eq("draft")
    expect(variant.attributes).to include(vat_class: "standard", stock_quantity: 0)
    expect(variant.attributes).not_to include(:track_stock, :allow_oversell)
  end

  it "reads booleans" do
    variant = group(base.merge("track_stock" => "0", "allow_oversell" => "TRUE")).variants.first

    expect(variant.attributes).to include(track_stock: false, allow_oversell: true)
  end

  it "reads the weight in grams" do
    expect(group(base.merge("weight" => "250")).variants.first.attributes).to include(weight_grams: 250)
    expect(codes(group(base.merge("weight" => "0,25")))).to eq([["invalid", "weight"]])
  end

  it "reads specs from the first row, and a differing later row as that variant's override" do
    rows = [base.merge("specification:Υλικό" => "Λινό | Μετάξι"), base.merge("specification:Υλικό" => ""),
            base.merge("specification:Υλικό" => "Βαμβάκι")]
    group = group(*rows)

    expect(group.product_attributes[:specifications]).to eq("Υλικό" => ["Λινό", "Μετάξι"])
    inherited = group.keyed(group.specifications)
    expect(group.variants.map { |variant| group.variant_attributes(variant, inherited)[:specifications] })
      .to eq([{}, {}, { "Υλικό" => ["Βαμβάκι"] }])
  end

  it "refuses a spec cell with no value, naming the column as the file spells it" do
    error = group(base.merge("specification:Υλικό" => "|")).errors.sole

    expect(error).to include(code: "invalid", field: "specification:Υλικό")
    expect(error[:message]).to start_with("specification:Υλικό ")
  end

  describe "value images" do
    let(:black) { base.merge("specification:Χρώμα" => "Μαύρο") }
    let(:white) { base.merge("specification:Χρώμα" => "Λευκό") }

    it "links them to the value on the first row of that value, after the images for every variant" do
      rows = [black.merge("image_urls" => "https://host/a.jpg", "image_urls:Χρώμα" => "https://host/b.jpg"),
              black, white.merge("image_urls:Χρώμα" => "https://host/c.jpg")]

      expect(group(*rows).images).to eq([
        ["https://host/a.jpg", {}], ["https://host/b.jpg", { "Χρώμα" => "Μαύρο" }],
        ["https://host/c.jpg", { "Χρώμα" => "Λευκό" }]
      ])
    end

    it "refuses them on a later row of the value" do
      rows = [black, white, black.merge("image_urls:Χρώμα" => "https://host/b.jpg")]

      expect(codes(group(*rows))).to eq([["invalid", "image_urls:Χρώμα"]])
    end

    it "takes a blank value cell as the first row's value" do
      rows = [black, base.merge("image_urls:Χρώμα" => "https://host/b.jpg")]

      expect(codes(group(*rows))).to eq([["invalid", "image_urls:Χρώμα"]])
    end
  end

  it "refuses a later row whose product cell differs" do
    conflict = group(base, base.merge("title" => "Other")).errors.first

    expect(conflict).to include(code: "product_cell_conflict", field: "title", row: 3)
  end

  it "accepts a later row whose product cell differs only by spaces" do
    expect(group(base, base.merge("title" => " First ")).errors).to be_empty
  end

  it "splits the category path into levels" do
    expect(group(base.merge("category" => "A > B")).category_path).to eq(["A", "B"])
  end

  it "refuses an empty category level" do
    expect(codes(group(base.merge("category" => "A >  > B")))).to eq([["invalid", "category"]])
  end

  it "refuses a list of categories" do
    expect(codes(group(base.merge("category" => "A > B|C")))).to eq([["invalid", "category"]])
  end

  it "refuses an image URL that is not http" do
    expect(codes(group(base.merge("image_urls" => "ftp://host/a.jpg")))).to eq([["invalid", "image_urls"]])
  end

  it "refuses more image URLs than a product may hold" do
    stub_const("Product::Image::MAX_PER_PRODUCT", 1)
    row = base.merge("image_urls" => "https://host/a.jpg|https://host/b.jpg")

    expect(codes(group(row))).to eq([["invalid", "image_urls"]])
  end

  it "refuses a number past the column's limit" do
    cents = (Product::Variant::MAX_INTEGER / 100) + 1

    expect(codes(group(base.merge("price" => cents.to_s)))).to eq([["invalid", "price"]])
    expect(codes(group(base.merge("pre_discount_price" => cents.to_s)))).to eq([["invalid", "pre_discount_price"]])
    expect(codes(group(base.merge("stock" => (Product::Variant::MAX_INTEGER + 1).to_s)))).to eq([["invalid", "stock"]])
  end

  it "encodes a Greek image file name and drops a repeated URL" do
    product = group(base.merge("image_urls" => "https://host/εικόνα.jpg|https://host/εικόνα.jpg"))

    expect(product.errors).to be_empty
    expect(product.images).to eq([["https://host/%CE%B5%CE%B9%CE%BA%CF%8C%CE%BD%CE%B1.jpg", {}]])
  end

  it "refuses a handle that is not a slug" do
    expect(codes(group(base.merge("handle" => "Not A Slug")))).to eq([["invalid", "handle"]])
  end

  it "refuses an unknown status or VAT class" do
    expect(codes(group(base.merge("status" => "sold")))).to eq([["invalid", "status"]])
    expect(codes(group(base.merge("vat_class" => "zero")))).to eq([["invalid", "vat_class"]])
  end
end
