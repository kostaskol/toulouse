require "rails_helper"

RSpec.describe Product::Import::Writer, :as_tenant do
  let(:base) { { "handle" => "first", "title" => "First", "price" => "1" } }
  let(:small) { base.merge("category" => create(:category).name, "specification:Μέγεθος" => "S") }
  let(:medium) { base.merge("specification:Μέγεθος" => "M") }

  before { create(:specification, name: "Μέγεθος", kind: "size", multiple: false, selectable: true) }

  # @return [Array(String, String)] the factory variant's selectable spec column and value
  def known(product)
    name, values = product.variants.first.specifications.first
    ["specification:#{name}", values.first]
  end

  def write(*rows) = described_class.new(Product::Import::Sheet.new(import_csv(rows)).groups.first).call

  it "creates a product with its variants, brand and category path" do
    entry = write(small.merge("brand" => "Maker", "category" => "A > B"), medium.merge("price" => "2"))
    product = Product.find_by!(slug: "first")

    expect(entry).to include(
      result: "created", product_id: product.id, created_brands: ["Maker"], created_categories: ["A", "A > B"]
    )
    expect(product.variants.map(&:price_cents)).to eq([100, 200])
    expect(product.category.name).to eq("B")
  end

  context "when the store needs weights" do
    before { Current.tenant.setting.update!(weight_required: true) }

    let(:published) { small.merge("status" => "published") }

    it "fails a new published product with no weight" do
      expect(write(published)[:error_details]).to contain_exactly(include(code: "weight_missing", field: "status"))
    end

    it "creates a new published product with a weight" do
      expect(write(published.merge("weight" => "250"))).to include(result: "created")
    end

    it "adds a variant with no weight to a published product" do
      write(published.merge("weight" => "250"))

      expect(write(medium)).to include(result: "updated")
    end
  end

  it "fails a new product with no category" do
    expect(write(base)[:error_details]).to contain_exactly(include(code: "blank", field: "category"))
  end

  it "reuses an existing brand and category" do
    parent = create(:category)
    create(:brand, name: "Maker")
    entry = write(base.merge("brand" => "Maker", "category" => parent.name))

    expect(entry).to include(created_brands: [], created_categories: [])
  end

  it "adds new variants to an existing product and skips the known ones, matched by selectable values" do
    product = create(:product, slug: "first")
    column, value = known(product)
    entry = write(base.merge(column => value), base.merge(column => "New"))

    expect(entry[:result]).to eq("updated")
    expect(product.variants.reload.map { |variant| variant.selection.values }).to contain_exactly([value], ["New"])
  end

  it "skips a product whose variants all exist" do
    product = create(:product, slug: "first")
    cents = product.variants.first.price_cents
    row = base.merge("title" => product.title, "price" => format("%d.%02d", cents / 100, cents % 100))

    expect(write(row.merge([known(product)].to_h))).to include(result: "skipped", warnings: [])
  end

  it "warns about each cell it ignores" do
    product = create(:product, slug: "first")
    column, value = known(product)
    images = column.sub("specification:", "image_urls:")
    entry = write(base.merge("title" => "Changed", "price" => "999", "image_urls" => "https://host/a.jpg",
                             column => value, images => "https://host/b.jpg"))

    expect(entry[:warnings].pluck(:code, :field)).to contain_exactly(
      ["product_cell_ignored", "title"], ["variant_cell_ignored", "price"], ["image_urls_ignored", "image_urls"],
      ["image_urls_ignored", images]
    )
  end

  it "reports a new row with no value for a selectable spec on that row" do
    create(:product, slug: "first")

    expect(write(base)[:error_details]).to contain_exactly(include(code: "selection_incomplete", row: 2))
  end

  it "writes specs on the product and overrides on its variants" do
    write(small.merge("specification:Υλικό" => "Λινό"), medium.merge("specification:Υλικό" => "Μετάξι"))
    product = Product.find_by!(slug: "first")

    expect(product.specifications).to eq("Μέγεθος" => ["S"], "Υλικό" => ["Λινό"])
    expect(product.variants.map(&:specifications)).to eq([{}, { "Μέγεθος" => ["M"], "Υλικό" => ["Μετάξι"] }])
  end

  it "warns once about a spec cell of an existing variant, and overrides the stored spec on a new variant" do
    product = create(:product, slug: "first", specifications: { "Υλικό" => ["Λινό"] })
    column, value = known(product)
    entry = write(base.merge(column => value, "specification:Υλικό" => "Μετάξι"),
                  base.merge(column => "New", "specification:Υλικό" => "Βαμβάκι"))

    specification_warnings = entry[:warnings].select { |warning| warning[:field].start_with?("specification:") }
    expect(specification_warnings.pluck(:code, :field, :stored))
      .to contain_exactly(["variant_cell_ignored", "specification:Υλικό", "Λινό"])
    added = product.variants.reload.find { |variant| variant.selection.values == ["New"] }
    expect(added.specifications["Υλικό"]).to eq(["Βαμβάκι"])
  end

  it "lets a new first row override the stored spec and a blank row inherit it" do
    product = create(:product, slug: "first", specifications: { "Υλικό" => ["Λινό"] })
    column, = known(product)
    first = base.merge("title" => product.title, column => "New")
    entry = write(first.merge("specification:Υλικό" => "Μετάξι"), first.merge(column => "Newer"))

    expect(entry).to include(result: "updated", warnings: [])
    added = product.variants.reload.to_h { |variant| [variant.selection.values.first, variant.specifications["Υλικό"]] }
    expect(added.values_at("New", "Newer")).to eq([["Μετάξι"], nil])
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
    create(:product, slug: "first").variants.first.update!(specifications: { "Μέγεθος" => ["S"] })
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
