require "rails_helper"

RSpec.describe Product::Search, :as_tenant do
  include ActiveJob::TestHelper

  def search(query, after: nil, limit: Paginates::DEFAULT_LIMIT, products: Product.all)
    described_class.new(query, products:, variants: Product::Variant.all).page(after:, limit:)
  end

  def found(query, **options) = search(query, **options).first

  describe "the search document" do
    it "follows the product title" do
      product = create(:product)
      product.update!(title: "Παπούτσια")

      expect(found("παπούτσια")).to eq([product])
    end

    it "takes the brand, the categories with their ancestors, and active option values" do
      parent = create(:category, name: "Παπούτσια")
      product = create(:product, brand: create(:brand), category_ids: [create(:category, parent:).id])
      option = product.variants.first.option_values.values.first

      expect(found(product.brand.name)).to eq([product])
      expect(found("παπούτσια")).to eq([product])
      expect(found(option)).to eq([product])
    end

    it "follows a variant's options and leaves out archived variants" do
      product = create(:product)
      variant = create(:product_variant, product:)
      option = variant.option_values.values.first
      expect(found(option)).to eq([product])

      variant.update!(status: "archived")

      expect(found(option)).to be_empty
    end

    it "refreshes once when a product saves with its variants" do
      allow(described_class).to receive(:refresh).and_call_original
      product = build(:product)
      product.variants << build(:product_variant, product:)
      product.save!

      expect(described_class).to have_received(:refresh).once
    end

    it "keeps the search columns out of the audit log" do
      product = create(:product, title: "Παπούτσια")
      product.update!(title: "Σανδάλια")

      expect(product.versions.last.object.keys).not_to include("search_document", "search_text")
    end

    it "follows a brand rename through a job" do
      brand = create(:brand)
      product = create(:product, brand:)
      perform_enqueued_jobs { brand.update!(name: "Παπούτσια") }

      expect(found("παπούτσια")).to eq([product])
    end

    it "follows a rename of an ancestor category through a job" do
      parent = create(:category)
      product = create(:product, category_ids: [create(:category, parent:).id])
      perform_enqueued_jobs { parent.update!(name: "Παπούτσια") }

      expect(found("παπούτσια")).to eq([product])
    end

    it "drops a deleted category through a job" do
      category = create(:category, name: "Παπούτσια")
      create(:product, category_ids: [category.id])
      perform_enqueued_jobs { category.destroy! }

      expect(found("παπούτσια")).to be_empty
    end
  end

  describe "matching" do
    it "ignores tonos, case and final sigma" do
      product = create(:product, title: "ΣΟΦΟΣ")

      expect(found("σοφός")).to eq([product])
    end

    it "keeps a decomposed accent inside its word" do
      product = create(:product, title: "Παπούτσια")

      expect(search("παπούτσια".unicode_normalize(:nfd)).values_at(0, 2)).to eq([[product], "exact"])
    end

    it "matches a half typed last word whose stem outgrows the whole word's" do
      product = create(:product, title: "Αθλητικά")

      expect(search("αθλητικ").values_at(0, 2)).to eq([[product], "exact"])
    end

    it "keeps a decimal in the query whole" do
      product = create(:product)
      option = product.option_names.first
      product.variants.first.update!(option_values: { option => "42.5" })

      expect(search("42.5").values_at(0, 2)).to eq([[product], "exact"])
    end

    it "matches inflected forms" do
      product = create(:product, title: "Παπούτσια")

      expect(found("παπούτσι")).to eq([product])
    end

    it "needs every term, and matches the last one as a prefix" do
      brand = create(:brand)
      product = create(:product, title: "Παπούτσια", brand:)
      create(:product, title: "Παπούτσια")

      expect(found("#{brand.name} παπου")).to eq([product])
    end

    it "ranks a title match above a description match" do
      titled = create(:product, title: "Παπούτσια")
      described = create(:product, description: "Παπούτσια")

      expect(found("παπούτσια")).to eq([titled, described])
    end

    it "puts a product whose SKU, barcode or MPN equals the query first" do
      coded = create(:product)
      titled = create(:product)
      coded.variants.first.update!(barcode: titled.title)

      expect(found(titled.title)).to eq([coded, titled])
    end

    it "keeps to the products it is given" do
      create(:product, title: "Παπούτσια")

      expect(found("παπούτσια", products: Product.published)).to be_empty
    end
  end

  describe "greeklish" do
    it "matches a greeklish query against Greek text" do
      product = create(:product, title: "Παπούτσια")

      expect(found("papoutsia")).to eq([product])
    end

    it "matches the last greeklish term as a prefix" do
      product = create(:product, title: "Παπούτσια")

      expect(found("papoutsi")).to eq([product])
    end

    it "falls back to trigrams for a greeklish typo" do
      product = create(:product, title: "Παπούτσια")

      expect(search("papoutsa").values_at(0, 2)).to eq([[product], "fuzzy"])
    end
  end

  describe "fuzzy fallback" do
    it "answers trigram matches when full text finds nothing" do
      product = create(:product, title: "Παπούτσια")

      products, _cursor, match = search("βαπούτσια")
      expect(products).to eq([product])
      expect(match).to eq("fuzzy")
    end

    it "stays exact when full text finds something" do
      create(:product, title: "Παπούτσια")

      expect(search("παπούτσια").last).to eq("exact")
    end
  end

  describe "pages" do
    it "walks the results one page at a time in rank order" do
      products = [create(:product, title: "Παπούτσια"), create(:product, description: "Παπούτσια")]
      first, cursor = search("παπούτσια", limit: 1)
      second, last_cursor = search("παπούτσια", after: cursor, limit: 1)

      expect(first + second).to eq(products)
      expect(last_cursor).to be_nil
    end

    it "stays fuzzy on a later page" do
      create_list(:product, 2, title: "Παπούτσια")
      _first, cursor = search("βαπούτσια", limit: 1)
      second, _cursor, match = search("βαπούτσια", after: cursor, limit: 1)

      expect(second.size).to eq(1)
      expect(match).to eq("fuzzy")
    end

    it "pages through a query that holds a question mark" do
      coded = create_list(:product, 2)
      query = "#{coded.first.slug}?"
      coded.each { |product| product.variants.first.update!(barcode: query) }
      first, cursor = search(query, limit: 1)

      expect(first + search(query, after: cursor, limit: 1).first).to match_array(coded)
    end

    ["page-2", Base64.urlsafe_encode64(["exact", 0, 0.5, "page-2"].to_json),
     Base64.urlsafe_encode64(["exact", 0, 1e39, SecureRandom.uuid].to_json),
     Base64.urlsafe_encode64(["exact", 0, 1e-50, SecureRandom.uuid].to_json)].each do |cursor|
      it "refuses the cursor #{cursor}" do
        expect { search("παπούτσια", after: cursor) }.to raise_error(described_class::InvalidCursor)
      end
    end
  end
end
