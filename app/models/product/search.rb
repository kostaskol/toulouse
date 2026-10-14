# Finds products for a typed query. A SKU, barcode or MPN hit comes first, then full text matches by rank.
# Trigram similarity takes over only when full text finds nothing.
class Product::Search
  MIN_LENGTH = 2
  MAX_LENGTH = 200
  MATCHES = ["exact", "fuzzy"].freeze
  # Marks too, so a decomposed accent does not split a word. A decimal stays whole, as Postgres keeps it.
  WORD = /[\p{L}\p{M}\p{N}]+(?:\.\p{N}+)*/

  class InvalidCursor < StandardError; end

  # Rebuilds the stored document a product is searched by.
  #
  # @param product [Product]
  def self.refresh(product)
    # Locked before reading, so two saves of one product cannot each write a document missing the other's change.
    Product.where(id: product.id).lock.pick(:id)
    categories = Category.names_with_ancestors(product.categorizations.pluck(:category_id))
    variants = product.variants.active.pluck(:id, :option_values)
    options = variants.flat_map { |_, values| values.values }
    own = [nil, *variants.map(&:first)]
    specifications = Product::SpecificationValue.where(product_id: product.id, variant_id: own).pluck(:value)
    fields = { "A" => product.title, "B" => product.brand&.name,
               "C" => [*categories, *options, *specifications].join(" "),
               "D" => product.description }

    # Skeletons are whole words, so they skip the stemmer.
    document = fields.map { "setweight(to_tsvector('search', ?) || to_tsvector('simple', ?), ?)" }.join(" || ")
    named = "#{product.title} #{product.brand&.name}"
    Product.where(id: product.id).update_all([
      "search_document = #{document}, search_text = ?",
      *fields.flat_map { |weight, text| [text.to_s, skeletons(text.to_s), weight] },
      "#{fold(named)} #{skeletons(named)}"
    ])
  end

  # @param text [String]
  # @return [String] the greeklish skeleton of each Greek word
  def self.skeletons(text)
    text.scan(WORD).select { |word| Greeklish.greek?(word) }.map { |word| Greeklish.skeleton(word) }.join(" ")
  end

  # Drops accents and case, and turns final sigma into sigma.
  #
  # @param text [String]
  # @return [String]
  def self.fold(text)
    text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.tr("ς", "σ")
  end

  # @param query [String] already checked against MIN_LENGTH and MAX_LENGTH
  # @param products [ActiveRecord::Relation<Product>] the products the caller may see
  # @param variants [ActiveRecord::Relation<Product::Variant>] the variants whose codes may match
  def initialize(query, products:, variants:)
    @query = query.strip
    @terms = @query.scan(WORD)
    @products = products
    @variants = variants
  end

  # @return [Array<String>] the words a category name must match
  attr_reader :terms

  # @param after [String, nil] a next_cursor from an earlier page
  # @param limit [Integer]
  # @param filter [Product::Filter, nil]
  # @return [Array(Array<Product>, String, nil, String)] the page, the next cursor and the match
  def page(after:, limit:, filter: nil)
    match, *key = after ? decode(after) : [self.match]
    products, next_cursor = page_of(match, key.presence, limit, filter)
    [products, next_cursor, match]
  end

  # Full text, unless it finds nothing. Filters play no part, so ticking one never swaps in fuzzy results.
  #
  # @return [String]
  def match
    @match ||= terms.any? && @products.where(exact.last).exists? ? "exact" : "fuzzy"
  end

  # @return [ActiveRecord::Relation<Product>] every product the query matches, before filters
  def matches
    return @products.none if terms.empty?

    @products.where(condition(match).last)
  end

  private

  def page_of(match, key, limit, filter)
    return [[], nil] if terms.empty?

    code, rank, matched = condition(match)
    scope = @products.where(matched).select("products.*", "#{code} AS search_code", "#{rank} AS search_rank")
    scope = filter.apply(scope) if filter
    # Bound apart, because the query quoted inside code and rank may hold a ? of its own.
    if key
      bound = Product.sanitize_sql(["?, ?::real, ?::uuid", *key])
      scope = scope.where("(#{code}, #{rank}, products.id) < (#{bound})")
    end
    records = scope.reorder(Arel.sql("search_code DESC, search_rank DESC, products.id DESC")).limit(limit + 1).to_a

    last = records[limit - 1]
    [records.first(limit), (encode(match, last) if records.size > limit)]
  end

  # Picks the SQL for one way of matching.
  #
  # @param match [String]
  # @return [Array(String, String, String)] the code hit flag, the rank and the match condition
  def condition(match) = match == "exact" ? exact : fuzzy

  def exact
    hits = @variants.where(sku: @query).or(@variants.where(barcode: @query)).or(@variants.where(mpn: @query))
                    .select(:product_id).to_sql
    text = "SELECT id FROM products WHERE search_document @@ #{tsquery}"
    # A UNION rather than OR, so each side can use its own index.
    ["(products.id IN (#{hits}))::int", "ts_rank(products.search_document, #{tsquery})",
     "products.id IN (#{hits} UNION #{text})"]
  end

  def fuzzy
    queries = [Product::Search.fold(@query)]
    queries << terms.map { |term| Greeklish.skeleton(term) }.join(" ") if terms.any? { |term| Greeklish.latin?(term) }
    queries = queries.map { |query| Product.connection.quote(query) }

    ["0", "GREATEST(#{queries.map { |query| "word_similarity(#{query}, products.search_text)" }.join(", ")})",
     queries.map { |query| "#{query} <% products.search_text" }.join(" OR ")]
  end

  # Every term must match, the last as a prefix. A Latin term may be greeklish, so its skeleton matches too. So
  # does a Greek last term: a half typed word can stem longer than the whole word.
  def tsquery
    parts = terms.each_with_index.map do |term, index|
      suffix = ":*" if index == terms.size - 1
      part = Product.sanitize_sql(["to_tsquery('search', ?)", "#{term}#{suffix}"])
      next part unless Greeklish.latin?(term) || (suffix && Greeklish.greek?(term))

      "(#{part} || #{Product.sanitize_sql(["to_tsquery('simple', ?)", "#{Greeklish.skeleton(term)}#{suffix}"])})"
    end
    "(#{parts.join(" && ")})"
  end

  def encode(match, product)
    Base64.urlsafe_encode64([match, product.search_code, product.search_rank, product.id].to_json, padding: false)
  end

  def decode(cursor)
    match, code, rank, id = JSON.parse(Base64.urlsafe_decode64(cursor.to_s))
    # A rank must fit a Postgres real, whose normal range is about 1.2e-38 to 3.4e38.
    rank_valid = rank.is_a?(Float) && (rank.zero? || rank.abs.between?(1e-38, 1e38))
    valid = MATCHES.include?(match) && [0, 1].include?(code) && rank_valid && Paginates::UUID.match?(id.to_s)
    raise InvalidCursor unless valid

    [match, code, rank, id]
  rescue ArgumentError, JSON::ParserError
    raise InvalidCursor
  end
end
