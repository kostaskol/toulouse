# Narrows a product list by category, brand, price, option values and stock, and counts what each choice leaves.
# Every group is disjunctive: its values OR together, and its counts leave out its own selection.
class Product::Filter
  KEYS = ["categories", "brands", "price_min", "price_max", "options", "available"].freeze
  RANGES = 4
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
    # Brackets go too, so a key fits inside filter[options][...].
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

    @options = options(params["options"])
    @available = available(params["available"])
  end

  def any?
    [@categories, @brands, @price_min, @price_max, @options.presence, @available].any?
  end

  # @param products [ActiveRecord::Relation<Product>]
  # @param except [Symbol, String, nil] the group to leave out, for its own counts: :categories, :brands, :price,
  #   or an option key
  # @return [ActiveRecord::Relation<Product>]
  def apply(products, except: nil)
    products = narrow(products, except:)
    return products unless @price_min || @price_max || @available || @options.except(except).any?

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
      options: option_facet(products)
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

  def options(value)
    return {} if value.nil?
    # One variant must hold every option filter, and no variant has more options than its product.
    raise Invalid, "filter[options]" unless value.is_a?(Hash) && value.size <= Product::MAX_OPTIONS

    value.to_h { |key, values| [key, strings(values, "filter[options][#{key}]")] }
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
      products = products.where(id: Product::Categorization.where(category_id: @subtree_ids).select(:product_id))
    end
    @brands && except != :brands ? products.where(brand_id: Brand.where(slug: @brands).select(:id)) : products
  end

  # Option and price filters hold on one variant, so a shopper can buy what matched.
  def variants(except: nil)
    scope = Product::Variant.active
    unless except == :price
      scope = scope.where(price_cents: @price_min..) if @price_min
      scope = scope.where(price_cents: ..@price_max) if @price_max
    end
    scope = scope.available if @available
    # Keys and values compare as the facets gave them, already folded.
    @options.except(except).reduce(scope) do |narrowed, (key, values)|
      narrowed.where(<<~SQL.squish, key, values)
        EXISTS (SELECT 1 FROM jsonb_each_text(product_variants.option_values) AS option
                WHERE #{self.class.fold_sql("option.key")} = ? AND #{self.class.fold_sql("option.value")} IN (?))
      SQL
    end
  end

  def category_facet(products, root)
    links = Product::Categorization.where(product_id: apply(products, except: :categories).select(:id))
                                   .select(:product_id, :category_id)
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
    ranges.size > 1 ? ranges : []
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

  def option_facet(products)
    rows = option_rows(products, nil)
    @options.each_key do |key|
      rows = rows.reject { |row| row["group_key"] == key } + option_rows(products, key)
    end

    groups = rows.group_by { |row| row["group_key"] }.map do |key, group_rows|
      (group, *), values = group_rows.partition { |row| row["whole_group"] == 1 }
      values = values.map { |row| { key: row["value_key"], label: row["value_label"], count: row["count"] } }
      { key:, label: group["group_label"], mode: "any", count: group["count"],
        values: values.sort_by { |value| natural(value[:key]) } }
    end
    groups.sort_by { |group| [-group[:count], group[:label]] }.map { |group| group.except(:count) }
  end

  # A row per value, plus a row per group with whole_group set, which counts the group's products.
  def option_rows(products, key)
    variants = variants(except: key).where(product_id: narrow(products).select(:id))
                                    .select(:product_id, :option_values)
    only = Product.sanitize_sql(["WHERE #{self.class.fold_sql("option.key")} = ?", key]) if key
    Product.connection.select_all(<<~SQL).to_a
      SELECT group_key, value_key, mode() WITHIN GROUP (ORDER BY name) AS group_label,
             mode() WITHIN GROUP (ORDER BY value) AS value_label, count(DISTINCT product_id) AS count,
             GROUPING(value_key) AS whole_group
      FROM (
        SELECT variants.product_id, option.key AS name, option.value,
               #{self.class.fold_sql("option.key")} AS group_key, #{self.class.fold_sql("option.value")} AS value_key
        FROM (#{variants.to_sql}) AS variants, jsonb_each_text(variants.option_values) AS option
        #{only}
      ) AS options
      GROUP BY GROUPING SETS ((group_key), (group_key, value_key))
    SQL
  end

  def natural(key)
    key.match?(NUMBER) ? [0, key.tr(",", ".").to_f, ""] : [1, 0, key]
  end
end
