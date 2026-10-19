# Narrows a product list by category, brand, price, attributes and stock, and counts what each choice leaves.
# An attribute is an option or a facet spec, grouped by folded name. A group is disjunctive unless its spec says
# all: then its values AND together and its counts narrow with its own selection.
class Product::Filter
  KEYS = ["categories", "brands", "price_min", "price_max", "attributes", "available"].freeze
  RANGES = 4
  # Each selected group adds a count query and a clause to every other query.
  MAX_ATTRIBUTES = 10
  NUMBER = /\A\d+(?:[.,]\d+)?\z/

  class Invalid < StandardError
    attr_reader :field

    # @param field [String] the request parameter at fault
    def initialize(field)
      @field = field
      super("#{field} is malformed")
    end
  end

  # Drops accents and case, and turns final sigma into sigma, in SQL.
  #
  # @param sql [String]
  # @return [String]
  def self.fold_sql(sql)
    # Brackets go too, so a key fits inside filter[attributes][...].
    "translate(lower(unaccent(#{sql})), 'ς[]', 'σ')"
  end

  # @param params [Hash, nil] the filter request parameter as plain values
  def initialize(params)
    params ||= {}
    raise Invalid, "filter" unless params.is_a?(Hash)

    unknown = params.keys - KEYS
    raise Invalid, "filter[#{unknown.first}]" if unknown.any?

    @categories = strings(params["categories"], "filter[categories]")
    @brands = strings(params["brands"], "filter[brands]")
    @price_min = price(params["price_min"], "filter[price_min]")
    @price_max = price(params["price_max"], "filter[price_max]")
    raise Invalid, "filter[price_min]" if @price_min && @price_max && @price_min > @price_max

    @attributes = attributes(params["attributes"])
    @available = available(params["available"])
  end

  def any?
    [@categories, @brands, @price_min, @price_max, @attributes.presence, @available].any?
  end

  # @param products [ActiveRecord::Relation<Product>]
  # @param except [Symbol, String, nil] the group to leave out, for its own counts: :categories, :brands, :price,
  #   or an attribute key
  # @return [ActiveRecord::Relation<Product>]
  def apply(products, except: nil)
    products = narrow(products, except:)
    return products unless @price_min || @price_max || @available || @attributes.except(except).any?

    products.where(id: variants(except:).select(:product_id))
  end

  # @param products [ActiveRecord::Relation<Product>] every product in the list, before filters
  # @param root [Category, nil] the category whose page lists them
  # @return [Hash]
  def facets(products, root: nil)
    {
      categories: category_facet(products, root),
      brands: brand_facet(products),
      price: price_facet(products),
      attributes: attribute_facet(products)
    }
  end

  private

  def strings(value, field)
    return if value.nil?
    raise Invalid, field unless value.is_a?(Array) && value.all?(String)

    value
  end

  def price(value, field)
    return if value.nil?
    raise Invalid, field unless value.is_a?(String) && value.match?(/\A\d+\z/)

    Integer(value, 10).tap { |cents| raise Invalid, field if cents > Product::Variant::MAX_INTEGER }
  end

  def attributes(value)
    return {} if value.nil?
    raise Invalid, "filter[attributes]" unless value.is_a?(Hash) && value.size <= MAX_ATTRIBUTES

    value.to_h { |key, values| [key, strings(values, "filter[attributes][#{key}]")] }
  end

  # @return [Set<String>] the keys of groups that AND their values
  def conjunctive
    @conjunctive ||= Specification.where(facet: true).mode_all.pluck(:key).to_set
  end

  # Each attribute of a variant: its options, and the facet specs it overrides or inherits from its product.
  #
  # @param variant [String] the SQL name of the variant row
  def pairs_sql(variant)
    <<~SQL.squish
      SELECT option.key AS name, option.value FROM jsonb_each_text(#{variant}.option_values) AS option
      UNION ALL
      SELECT specifications.name, spec.value
      FROM product_specification_values AS spec JOIN specifications ON specifications.id = spec.specification_id
      WHERE specifications.facet AND spec.product_id = #{variant}.product_id
        AND (spec.variant_id = #{variant}.id OR (spec.variant_id IS NULL AND NOT EXISTS (
          SELECT 1 FROM product_specification_values AS own
          WHERE own.variant_id = #{variant}.id AND own.specification_id = spec.specification_id)))
    SQL
  end

  def available(value)
    return false if value.nil? || value == "false"
    raise Invalid, "filter[available]" unless value == "true"

    true
  end

  # Category and brand filters only. A count over variants applies the variant filters itself.
  def narrow(products, except: nil)
    if @categories && except != :categories
      @subtree_ids ||= Category.subtree_ids(Category.where(slug: @categories).ids)
      products = products.where(category_id: @subtree_ids)
    end
    @brands && except != :brands ? products.where(brand_id: Brand.where(slug: @brands).select(:id)) : products
  end

  # Attribute and price filters hold on one variant, so a shopper can buy what matched.
  def variants(except: nil)
    scope = Product::Variant.active
    unless except == :price
      scope = scope.where(price_cents: @price_min..) if @price_min
      scope = scope.where(price_cents: ..@price_max) if @price_max
    end
    scope = scope.available if @available
    # One clause per group whatever its mode, so MAX_ATTRIBUTES bounds the query. Keys and values compare as the
    # facets gave them, already folded.
    name = self.class.fold_sql("attribute.name")
    value = self.class.fold_sql("attribute.value")
    @attributes.except(except).reduce(scope) do |narrowed, (key, values)|
      # At least one, so an empty list matches nothing in either mode.
      needed = conjunctive.include?(key) ? [values.uniq.size, 1].max : 1
      narrowed.where(<<~SQL.squish, key, values, needed)
        (SELECT count(DISTINCT #{value}) FROM (#{pairs_sql("product_variants")}) AS attribute
         WHERE #{name} = ? AND #{value} IN (?)) >= ?
      SQL
    end
  end

  def category_facet(products, root)
    links = Product.where(id: apply(products, except: :categories).select(:id)).select("id AS product_id", :category_id)
    counts = Category.connection.select_rows(<<~SQL).to_h
      WITH RECURSIVE links(product_id, category_id) AS (
        #{links.to_sql}
        UNION
        SELECT links.product_id, categories.parent_id
        FROM links JOIN categories ON categories.id = links.category_id
        WHERE categories.parent_id IS NOT NULL
      )
      SELECT category_id, count(DISTINCT product_id) FROM links GROUP BY category_id
    SQL
    category_tree(Category.where(id: counts.keys).by_parent, root&.id, counts)
  end

  def category_tree(by_parent, parent_id, counts)
    by_parent.fetch(parent_id, []).map do |category|
      category.slice(:id, :name, :slug).merge(count: counts.fetch(category.id),
                                              children: category_tree(by_parent, category.id, counts))
    end
  end

  def brand_facet(products)
    counts = Product.where(id: apply(products, except: :brands).select(:id)).where.not(brand_id: nil)
                    .group(:brand_id).count
    Brand.where(id: counts.keys).order(:name).map { |brand| brand.slice(:name, :slug).merge(count: counts[brand.id]) }
  end

  def price_facet(products)
    # Distinct per product, so fifty sizes at one price weigh as one.
    prices = variants(except: :price).where(product_id: narrow(products).select(:id))
                                     .select(:product_id, :price_cents).distinct.to_sql
    # Bound apart, because a search query quoted inside prices may hold a ? of its own.
    quantiles = Product.sanitize_sql(["percentile_disc(ARRAY[?]::float8[]) WITHIN GROUP (ORDER BY price_cents)",
                                      (1...RANGES).map { |n| n.fdiv(RANGES) }])
    min, max, quantiles = Product.connection.select_all(<<~SQL).cast_values.first
      SELECT min(price_cents), max(price_cents), #{quantiles} FROM (#{prices}) AS prices
    SQL
    { min:, max:, ranges: min ? price_ranges(prices, min, max, quantiles) : [] }
  end

  # Open at both ends, so an outlier price shows on no range.
  def price_ranges(prices, min, max, quantiles)
    edges = quantiles.map { |cents| nice(cents) }.uniq.select { |edge| edge > min && edge <= max }
    ranges = [nil, *edges].zip([*edges.map { |edge| edge - 1 }, nil])
    counts = ranges.map do |low, high|
      Product.sanitize_sql(["count(DISTINCT product_id) FILTER (WHERE price_cents BETWEEN ? AND ?)",
                            low || 0, high || Product::Variant::MAX_INTEGER])
    end
    counts = Product.connection.select_rows("SELECT #{counts.join(", ")} FROM (#{prices}) AS prices").first
    ranges = ranges.zip(counts).filter_map { |(low, high), count| { min: low, max: high, count: } if count.positive? }
    # A range of one product only repeats a price the shopper already sees.
    ranges.size > 1 && ranges.none? { |range| range[:count] == 1 } ? ranges : []
  end

  # Rounds to a 1, 2 or 5 step in whole euros, about a fifth of the amount.
  def nice(cents)
    euros = cents / 100.0
    target = euros / 5
    step = 1
    if target >= 1
      scale = 10**Math.log10(target).floor
      step = [5, 2, 1].map { |factor| factor * scale }.find { |candidate| candidate <= target }
    end
    (euros / step).round * step * 100
  end

  def attribute_facet(products)
    rows = attribute_rows(products, nil)
    @attributes.each_key do |key|
      own = attribute_rows(products, key)
      # A conjunctive group lists every value, so a pick that empties the list can be undone, but counts narrow.
      if conjunctive.include?(key)
        narrowed = rows.select { |row| row["group_key"] == key }.to_h { |row| [row["value_key"], row["count"]] }
        own = own.map { |row| row.merge("count" => narrowed.fetch(row["value_key"], 0)) }
      end
      rows = rows.reject { |row| row["group_key"] == key } + own
    end

    groups = rows.group_by { |row| row["group_key"] }.map do |key, group_rows|
      (group, *), values = group_rows.partition { |row| row["whole_group"] == 1 }
      values = values.map { |row| { key: row["value_key"], label: row["value_label"], count: row["count"] } }
      mode = conjunctive.include?(key) ? "all" : "any"
      { key:, label: group["group_label"], mode:, count: group["count"],
        values: values.sort_by { |value| natural(value[:key]) } }
    end
    groups.sort_by { |group| [-group[:count], group[:label]] }.map { |group| group.except(:count) }
  end

  # A row per value, plus a row per group with whole_group set, which counts the group's products.
  def attribute_rows(products, key)
    variants = variants(except: key).where(product_id: narrow(products).select(:id))
                                    .select(:id, :product_id, :option_values)
    only = Product.sanitize_sql(["WHERE #{self.class.fold_sql("attribute.name")} = ?", key]) if key
    Product.connection.select_all(<<~SQL).to_a
      SELECT group_key, value_key, mode() WITHIN GROUP (ORDER BY name) AS group_label,
             mode() WITHIN GROUP (ORDER BY value) AS value_label, count(DISTINCT product_id) AS count,
             GROUPING(value_key) AS whole_group
      FROM (
        SELECT variants.product_id, attribute.name, attribute.value,
               #{self.class.fold_sql("attribute.name")} AS group_key,
               #{self.class.fold_sql("attribute.value")} AS value_key
        FROM (#{variants.to_sql}) AS variants, LATERAL (#{pairs_sql("variants")}) AS attribute
        #{only}
      ) AS attributes
      GROUP BY GROUPING SETS ((group_key), (group_key, value_key))
    SQL
  end

  def natural(key)
    key.match?(NUMBER) ? [0, key.tr(",", ".").to_f, ""] : [1, 0, key]
  end
end
