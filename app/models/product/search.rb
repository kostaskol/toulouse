# Finds products for a typed query. A SKU, barcode or MPN hit comes first, then full text matches by rank.
# Trigram similarity takes over only when full text finds nothing.
class Product::Search
  MIN_LENGTH = 2
  MAX_LENGTH = 200
  MATCHES = ["exact", "fuzzy"].freeze

  class InvalidCursor < StandardError; end

  # Rebuilds the stored document a product is searched by.
  #
  # @param product [Product]
  def self.refresh(product)
    # Locked before reading, so two saves of one product cannot each write a document missing the other's change.
    Product.where(id: product.id).lock.pick(:id)
    categories = Category.names_with_ancestors(product.categorizations.pluck(:category_id))
    options = product.variants.active.pluck(:option_values).flat_map(&:values)
    fields = { "A" => product.title, "B" => product.brand&.name, "C" => [*categories, *options].join(" "),
               "D" => product.description }

    document = fields.map { "setweight(to_tsvector('search', ?), ?)" }.join(" || ")
    Product.where(id: product.id).update_all([
      "search_document = #{document}, search_text = ?",
      *fields.flat_map { |weight, text| [text.to_s, weight] }, fold("#{product.title} #{product.brand&.name}")
    ])
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
    @terms = @query.scan(/[\p{L}\p{N}]+/)
    @products = products
    @variants = variants
  end

  # @return [Array<String>] the words a category name must match
  attr_reader :terms

  # @param after [String, nil] a next_cursor from an earlier page
  # @param limit [Integer]
  # @return [Array(Array<Product>, String, nil, String)] the page, the next cursor and the match
  def page(after:, limit:)
    match, *key = after ? decode(after) : ["exact"]
    products, next_cursor = page_of(match, key.presence, limit)
    if products.empty? && after.nil?
      match = "fuzzy"
      products, next_cursor = page_of(match, nil, limit)
    end

    [products, next_cursor, match]
  end

  private

  def page_of(match, key, limit)
    return [[], nil] if terms.empty?

    code, rank, condition = match == "exact" ? exact : fuzzy
    scope = @products.where(condition).select("products.*", "#{code} AS search_code", "#{rank} AS search_rank")
    # Bound apart, because the query quoted inside code and rank may hold a ? of its own.
    if key
      bound = Product.sanitize_sql(["?, ?::real, ?::uuid", *key])
      scope = scope.where("(#{code}, #{rank}, products.id) < (#{bound})")
    end
    records = scope.reorder(Arel.sql("search_code DESC, search_rank DESC, products.id DESC")).limit(limit + 1).to_a

    last = records[limit - 1]
    [records.first(limit), (encode(match, last) if records.size > limit)]
  end

  def exact
    hits = @variants.where(sku: @query).or(@variants.where(barcode: @query)).or(@variants.where(mpn: @query))
                    .select(:product_id).to_sql
    text = "SELECT id FROM products WHERE search_document @@ #{tsquery}"
    # A UNION rather than OR, so each side can use its own index.
    ["(products.id IN (#{hits}))::int", "ts_rank(products.search_document, #{tsquery})",
     "products.id IN (#{hits} UNION #{text})"]
  end

  def fuzzy
    query = Product.connection.quote(Product::Search.fold(@query))
    ["0", "word_similarity(#{query}, products.search_text)", "#{query} <% products.search_text"]
  end

  # Every term must match. The last one matches as a prefix, since the shopper may still be typing it.
  def tsquery
    parts = terms.each_with_index.map do |term, index|
      Product.sanitize_sql(["to_tsquery('search', ?)", index == terms.size - 1 ? "#{term}:*" : term])
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
