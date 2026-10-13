require "rails_helper"

RSpec.describe Product::Import::Writer, :as_tenant do
  let(:base) { { "handle" => "first", "title" => "First", "price" => "1" } }
  let(:small) { base.merge("option1_name" => "Size", "option1_value" => "S") }
  let(:medium) { base.merge("option1_value" => "M") }

  def write(*rows) = described_class.new(Product::Import::Sheet.new(import_csv(rows)).groups.first).call

  it "creates a product with its variants, brand and category path" do
    entry = write(small.merge("brand" => "Maker", "categories" => "A > B"), medium.merge("price" => "2"))
    product = Product.find_by!(slug: "first")

    expect(entry).to include(
      result: "created", product_id: product.id, created_brands: ["Maker"], created_categories: ["A", "A > B"]
    )
    expect(product.variants.map(&:price_cents)).to eq([100, 200])
    expect(product.categories.map(&:name)).to eq(["B"])
  end

  it "reuses an existing brand and category" do
    parent = create(:category)
    create(:brand, name: "Maker")
    entry = write(base.merge("brand" => "Maker", "categories" => parent.name))

    expect(entry).to include(created_brands: [], created_categories: [])
  end

  it "adds new variants to an existing product and skips the known ones" do
    product = create(:product, slug: "first", option_names: ["Size"])
    known = product.variants.first.option_values["Size"]
    entry = write(base.merge("option1_name" => "Size", "option1_value" => known), base.merge("option1_value" => "New"))

    expect(entry[:result]).to eq("updated")
    expect(product.variants.reload.map { |variant| variant.option_values["Size"] }).to include(known, "New")
  end

  it "skips a product whose variants all exist" do
    product = create(:product, slug: "first", option_names: [])
    cents = product.variants.first.price_cents
    row = base.merge("title" => product.title, "price" => format("%d.%02d", cents / 100, cents % 100))

    expect(write(row)).to include(result: "skipped", warnings: [])
  end

  it "warns about each cell it ignores" do
    create(:product, slug: "first", option_names: [])
    entry = write(base.merge("title" => "Changed", "price" => "999", "image_urls" => "https://host/a.jpg"))

    expect(entry[:warnings].pluck(:code, :field)).to contain_exactly(
      ["product_cell_ignored", "title"], ["variant_cell_ignored", "price"], ["image_urls_ignored", "image_urls"]
    )
  end

  it "fails an existing product whose option names differ" do
    create(:product, slug: "first", option_names: ["Size"])
    entry = write(base.merge("option1_name" => "Colour", "option1_value" => "Red"))

    expect(entry[:error_details].pluck(:code)).to eq(["option_names_mismatch"])
  end

  it "reports a variant's model error on its row" do
    entry = write(small, medium.merge("pre_discount_price" => "0.5"))

    expect(entry[:error_details]).to contain_exactly(include(row: 3, field: "pre_discount_price"))
  end

  it "fails a new product whose rows repeat a SKU" do
    entry = write(small.merge("sku" => "first-sku"), medium.merge("sku" => "first-sku"))

    expect(entry[:result]).to eq("failed")
    expect(entry[:error_details]).to include(include(code: "taken", field: "sku", row: 3))
  end

  it "reports a new variant's error on its own row" do
    create(:product, slug: "first", option_names: ["Size"])
    entry = write(small, medium.merge("pre_discount_price" => "0.5"))

    expect(entry[:error_details]).to contain_exactly(include(row: 3, field: "pre_discount_price"))
  end

  it "reports a variant's base error without a field" do
    stub_const("Product::Variant::MAX_PER_PRODUCT", 1)
    entry = write(small, medium)

    expect(entry[:error_details]).to include(include(code: "too_many_variants", row: 3))
    expect(entry[:error_details].pluck(:field)).to all(be_nil)
  end

  it "rolls back a brand made for a failed product" do
    write(small.merge("brand" => "Maker"), medium.merge("pre_discount_price" => "0.5"))

    expect(Brand.where(name: "Maker")).to be_empty
  end
end
