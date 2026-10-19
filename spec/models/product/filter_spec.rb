require "rails_helper"

RSpec.describe Product::Filter, :as_tenant do
  # @param variants [Array<Hash>] each with `options` and optional variant attributes
  def product_with(*variants, **attributes)
    product = build(:product, option_names: variants.first.fetch(:options).keys, **attributes)
    product.variants = variants.map do |variant|
      build(:product_variant, product:, option_values: variant.fetch(:options), **variant.except(:options))
    end
    product.tap(&:save!)
  end

  def filtered(params) = described_class.new(params).apply(Product.all)

  def facets(params = {}, root: nil)
    described_class.new(params).facets(Product.all, root:)
  end

  def fold(text) = Product.connection.select_value("SELECT #{described_class.fold_sql(Product.connection.quote(text))}")

  describe "filtering" do
    it "narrows to a category's subtree, several categories together" do
      parent = create(:category)
      child = create(:product, category: create(:category, parent:))
      other = create(:product)
      create(:product)

      expect(filtered("categories" => [parent.slug])).to eq([child])
      expect(filtered("categories" => [parent.slug, other.category.slug])).to contain_exactly(child, other)
    end

    it "narrows to brands" do
      branded = create(:product, brand: create(:brand))
      create(:product, brand: create(:brand))

      expect(filtered("brands" => [branded.brand.slug])).to eq([branded])
    end

    it "keeps prices within both edges" do
      cheap, dear = create_list(:product, 2)
      low = cheap.variants.first.price_cents
      high = dear.variants.first.price_cents

      expect(filtered("price_min" => low.to_s, "price_max" => low.to_s)).to eq([cheap])
      expect(filtered("price_min" => (low + 1).to_s)).to eq([dear])
      expect(filtered("price_max" => (high - 1).to_s)).to eq([cheap])
    end

    it "needs one variant to hold every option and price filter" do
      split = product_with({ options: { "Χρώμα" => "Μαύρο", "Μέγεθος" => "40" } },
                           { options: { "Χρώμα" => "Κόκκινο", "Μέγεθος" => "42" } })
      whole = product_with({ options: { "Χρώμα" => "Μαύρο", "Μέγεθος" => "42" } })
      options = { fold("Χρώμα") => [fold("Μαύρο")], fold("Μέγεθος") => [fold("42")] }

      expect(filtered("attributes" => options)).to eq([whole])
      expect(filtered("attributes" => options.except(fold("Μέγεθος")))).to contain_exactly(split, whole)
    end

    it "matches option values of any spelling by their folded key" do
      product = product_with({ options: { "ΧΡΏΜΑ" => "ΜΑΎΡΟΣ" } })

      expect(filtered("attributes" => { fold("χρωμα") => [fold("μαυρος")] })).to eq([product])
    end

    it "keeps brackets out of an attribute key" do
      product = product_with({ options: { "Μέγεθος [EU]" => "42" } })
      key = facets[:attributes].first[:key]

      expect(key).not_to match(/[\[\]]/)
      expect(filtered("attributes" => { key => [fold("42")] })).to eq([product])
    end

    it "leaves out archived variants" do
      product = product_with({ options: { "Χρώμα" => "Μαύρο" } }, { options: { "Χρώμα" => "Κόκκινο" } })
      product.variants.last.update!(status: "archived")

      expect(filtered("attributes" => { fold("Χρώμα") => [fold("Κόκκινο")] })).to be_empty
    end

    describe "with specifications" do
      let!(:screen) { Specification.create!(name: "Οθόνη", facet: true) }

      it "matches a product's spec on every variant, unless the variant overrides it" do
        product = product_with({ options: { "Μέγεθος" => "S" } }, { options: { "Μέγεθος" => "M" } },
                               specifications: { "Οθόνη" => ["6.1"] })
        product.variants.last.update!(specifications: { "Οθόνη" => ["6.7"] })
        small = { fold("Οθόνη") => [fold("6.1")], fold("Μέγεθος") => [fold("S")] }

        expect(filtered("attributes" => small)).to eq([product])
        expect(filtered("attributes" => small.merge(fold("Μέγεθος") => [fold("M")]))).to be_empty
        expect(filtered("attributes" => { fold("Οθόνη") => [fold("6.7")] })).to eq([product])
      end

      it "matches an option and a spec of one name as one group" do
        option = product_with({ options: { "Οθόνη" => "6.1" } })
        spec = product_with({ options: { "Μέγεθος" => "S" } }, specifications: { "Οθόνη" => ["6.1"] })

        expect(filtered("attributes" => { fold("Οθόνη") => [fold("6.1")] })).to contain_exactly(option, spec)
      end

      it "needs every value of a conjunctive group" do
        screen.update!(mode: "all")
        both = create(:product, option_names: [], specifications: { "Οθόνη" => ["OLED", "120 Hz"] })
        create(:product, option_names: [], specifications: { "Οθόνη" => ["OLED"] })

        expect(filtered("attributes" => { fold("Οθόνη") => [fold("OLED"), fold("120 Hz")] })).to eq([both])
      end

      it "reads a conjunctive group as one clause, however many values it holds" do
        screen.update!(mode: "all")
        values = [fold("OLED"), fold("120 Hz")]

        sql = described_class.new("attributes" => { fold("Οθόνη") => values }).apply(Product.all).to_sql

        expect(sql.scan("count(DISTINCT").size).to eq(1)
      end

      it "matches nothing for an empty list, whatever the mode" do
        create(:product, option_names: [], specifications: { "Οθόνη" => ["6.1"] })

        expect(filtered("attributes" => { fold("Οθόνη") => [] })).to be_empty
        screen.update!(mode: "all")
        expect(filtered("attributes" => { fold("Οθόνη") => [] })).to be_empty
      end

      it "matches nothing for a spec that is not a facet" do
        screen.update!(facet: false)
        create(:product, option_names: [], specifications: { "Οθόνη" => ["6.1"] })

        expect(filtered("attributes" => { fold("Οθόνη") => [fold("6.1")] })).to be_empty
      end
    end

    it "keeps to variants a shopper can buy when asked" do
      sold_out = create(:product)
      sold_out.variants.first.update!(track_stock: true, stock_quantity: 0)

      expect(filtered("available" => "false")).to eq([sold_out])
      expect(filtered("available" => "true")).to be_empty
    end

    it "matches nothing for an unknown key" do
      create(:product)

      expect(filtered("categories" => [SecureRandom.hex(4)])).to be_empty
      expect(filtered("attributes" => { SecureRandom.hex(4) => [SecureRandom.hex(4)] })).to be_empty
    end

    {
      "a string" => [nil, "filter"],
      "an unknown key" => [{ "colour" => [] }, "filter[colour]"],
      "a category that is not a list" => [{ "categories" => "slug" }, "filter[categories]"],
      "a price that is not a whole number" => [{ "price_min" => "1.5" }, "filter[price_min]"],
      "a price past the column" => [{ "price_max" => (Product::Variant::MAX_INTEGER + 1).to_s }, "filter[price_max]"],
      "a minimum above the maximum" => [{ "price_min" => "2", "price_max" => "1" }, "filter[price_min]"],
      "attributes that are not keyed" => [{ "attributes" => ["value"] }, "filter[attributes]"],
      "more attribute groups than the cap" => [
        { "attributes" => (0..described_class::MAX_ATTRIBUTES).to_h { |n| [n.to_s, ["value"]] } }, "filter[attributes]"
      ],
      "attribute values that are not a list" => [{ "attributes" => { "key" => "value" } }, "filter[attributes][key]"],
      "an available flag that is not a boolean" => [{ "available" => "yes" }, "filter[available]"]
    }.each do |name, (params, field)|
      it "refuses #{name}" do
        expect { described_class.new(params || "filter") }
          .to raise_error(described_class::Invalid) { |error| expect(error.field).to eq(field) }
      end
    end
  end

  describe "facets" do
    it "counts each category over its subtree as a pruned tree" do
      root = create(:category)
      child = create(:category, parent: root)
      create(:category, parent: root)
      create(:product, category: root)
      create(:product, category: child)

      expect(facets[:categories]).to eq([
        root.slice(:id, :name, :slug).merge(count: 2, children: [
          child.slice(:id, :name, :slug).merge(count: 1, children: [])
        ])
      ])
    end

    it "starts the tree below the page's category" do
      root = create(:category)
      child = create(:category, parent: root)
      create(:product, category: child)

      expect(facets(root:)[:categories].pluck(:id)).to eq([child.id])
    end

    it "counts a group without its own selection and with every other" do
      picked, other = create_list(:category, 2)
      brand = create(:brand)
      create(:product, brand:, category: picked)
      create(:product, brand:, category: other)
      create(:product, category: other)

      result = facets({ "categories" => [picked.slug], "brands" => [brand.slug] })

      expect(result[:categories].to_h { |category| [category[:id], category[:count]] })
        .to eq(picked.id => 1, other.id => 1)
      expect(result[:brands]).to eq([brand.slice(:name, :slug).merge(count: 1)])
    end

    it "lists brands by name and leaves out products with none" do
      second = create(:brand, name: "Β")
      first = create(:brand, name: "Α")
      create(:product, brand: second)
      create_list(:product, 2, brand: first)
      create(:product)

      expect(facets[:brands]).to eq([first.slice(:name, :slug).merge(count: 2),
                                     second.slice(:name, :slug).merge(count: 1)])
    end

    describe "price" do
      it "gives the lowest and highest price, ignoring its own filter" do
        products = create_list(:product, 2)
        prices = products.map { |product| product.variants.first.price_cents }

        expect(facets({ "price_min" => prices.max.to_s })[:price]).to include(min: prices.min, max: prices.max)
      end

      it "splits by quantile into ranges open at both ends, edges on round euros" do
        prices = (1..8).map { |n| n * 1000 } * 2
        prices.each { |cents| product_with({ options: { "Χρώμα" => "Μαύρο" }, price_cents: cents }) }

        expect(facets[:price][:ranges]).to eq([
          { min: nil, max: 1999, count: 2 },
          { min: 2000, max: 3999, count: 4 },
          { min: 4000, max: 5999, count: 4 },
          { min: 6000, max: nil, count: 6 }
        ])
      end

      it "gives no ranges when one would hold a single product" do
        prices = (1..8).map { |n| n * 1000 }
        prices.each { |cents| product_with({ options: { "Χρώμα" => "Μαύρο" }, price_cents: cents }) }

        expect(facets[:price]).to include(min: prices.min, max: prices.max, ranges: [])
      end

      it "counts a product in every range one of its variants falls in" do
        prices = (1..8).map { |n| n * 1000 }
        prices.each { |cents| product_with({ options: { "Χρώμα" => "Μαύρο" }, price_cents: cents }) }
        product_with({ options: { "Χρώμα" => "Μαύρο" }, price_cents: prices.min },
                     { options: { "Χρώμα" => "Κόκκινο" }, price_cents: prices.max })

        expect(facets[:price][:ranges].sum { |range| range[:count] }).to eq(Product.count + 1)
      end

      it "gives no ranges for one price" do
        create(:product)

        expect(facets[:price][:ranges]).to be_empty
      end

      it "gives no prices for no products" do
        expect(facets[:price]).to eq(min: nil, max: nil, ranges: [])
      end
    end

    describe "attributes" do
      it "groups by folded name and value, labelled by the most common spelling" do
        product_with({ options: { "Χρώμα" => "Μαύρο" } })
        product_with({ options: { "Χρώμα" => "μαύρο" } })
        product_with({ options: { "χρωμα" => "Μαύρο" } })

        expect(facets[:attributes]).to eq([
          { key: fold("Χρώμα"), label: "Χρώμα", mode: "any",
            values: [{ key: fold("Μαύρο"), label: "Μαύρο", count: 3 }] }
        ])
      end

      it "orders values naturally and groups by product count" do
        product_with({ options: { "Μέγεθος" => "10" } }, { options: { "Μέγεθος" => "9" } },
                     { options: { "Μέγεθος" => "9,5" } }, { options: { "Μέγεθος" => "S" } })
        product_with({ options: { "Μέγεθος" => "M" } })
        product_with({ options: { "Χρώμα" => "Μαύρο" } })

        groups = facets[:attributes]

        expect(groups.pluck(:label)).to eq(["Μέγεθος", "Χρώμα"])
        expect(groups.first[:values].pluck(:label)).to eq(["9", "9,5", "10", "M", "S"])
      end

      it "folds an option and a facet spec of one name into one group, in the spec's mode" do
        Specification.create!(name: "Χρώμα", facet: true, mode: "all")
        product_with({ options: { "Χρώμα" => "Μαύρο" } })
        create(:product, option_names: [], specifications: { "χρώμα" => ["Μαύρο", "Λευκό"] })
        create(:product, option_names: [], specifications: { "Μη φίλτρο" => ["Τιμή"] })

        expect(facets[:attributes]).to eq([
          { key: fold("Χρώμα"), label: "Χρώμα", mode: "all",
            values: [{ key: fold("Λευκό"), label: "Λευκό", count: 1 },
                     { key: fold("Μαύρο"), label: "Μαύρο", count: 2 }] }
        ])
      end

      it "keeps a conjunctive group and its values when its picks match nothing" do
        Specification.create!(name: "Χρώμα", facet: true, mode: "all")
        create(:product, option_names: [], specifications: { "Χρώμα" => ["Μαύρο"] })
        create(:product, option_names: [], specifications: { "Χρώμα" => ["Λευκό"] })

        group = facets({ "attributes" => { fold("Χρώμα") => [fold("Μαύρο"), fold("Λευκό")] } })[:attributes].first

        expect(group).to include(mode: "all")
        expect(group[:values].to_h { |value| [value[:label], value[:count]] }).to eq("Λευκό" => 0, "Μαύρο" => 0)
      end

      it "narrows a conjunctive group's counts by its own selection" do
        Specification.create!(name: "Χρώμα", facet: true, mode: "all")
        create(:product, option_names: [], specifications: { "Χρώμα" => ["Μαύρο", "Λευκό"] })
        create(:product, option_names: [], specifications: { "Χρώμα" => ["Λευκό"] })

        values = facets({ "attributes" => { fold("Χρώμα") => [fold("Μαύρο")] } }).fetch(:attributes).first[:values]

        expect(values.to_h { |value| [value[:label], value[:count]] }).to eq("Λευκό" => 1, "Μαύρο" => 1)
      end

      it "counts a group without its own selection but with the others on the same variant" do
        product_with({ options: { "Χρώμα" => "Μαύρο", "Μέγεθος" => "42" } })
        product_with({ options: { "Χρώμα" => "Κόκκινο", "Μέγεθος" => "42" } })
        product_with({ options: { "Χρώμα" => "Κόκκινο", "Μέγεθος" => "40" } },
                     { options: { "Χρώμα" => "Μαύρο", "Μέγεθος" => "42" } })

        groups = facets({ "attributes" => { fold("Χρώμα") => [fold("Μαύρο")] } }).fetch(:attributes)
                 .to_h { |group| [group[:label], group[:values].to_h { |v| [v[:label], v[:count]] }] }

        expect(groups).to eq("Χρώμα" => { "Κόκκινο" => 2, "Μαύρο" => 2 }, "Μέγεθος" => { "42" => 2 })
      end
    end
  end
end
