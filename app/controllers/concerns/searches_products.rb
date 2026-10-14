module SearchesProducts
  extend ActiveSupport::Concern
  include RendersFailures
  include Paginates

  FAILURES = {
    blank: Failure.new(status: :unprocessable_content, code: "blank", message: "The search query is blank."),
    query_too_short: Failure.new(
      status: :unprocessable_content,
      code: "query_too_short",
      message: "The search query needs at least #{Product::Search::MIN_LENGTH} characters."
    ),
    query_too_long: Failure.new(
      status: :unprocessable_content,
      code: "query_too_long",
      message: "The search query takes at most #{Product::Search::MAX_LENGTH} characters."
    )
  }.freeze

  included do
    rescue_from(Product::Search::InvalidCursor) { render_failure(Paginates::FAILURES.fetch(:invalid_cursor)) }
  end

  private

  # Renders a failure when the query is blank, too short or too long.
  #
  # @param query [String, nil]
  # @param field [String] the request parameter that carries the query
  # @return [Boolean] whether it rendered one
  def refuse_query(query, field:)
    # q[]= arrives as an array, which counts as no query. NFC, so a decomposed accent is not a second character.
    length = query.is_a?(String) ? query.unicode_normalize(:nfc).squish.length : 0
    key =
      if length.zero? then :blank
      elsif length < Product::Search::MIN_LENGTH then :query_too_short
      elsif length > Product::Search::MAX_LENGTH then :query_too_long
      end
    render_failure(FAILURES.fetch(key), field:) if key
    key.present?
  end

  # @param search [Product::Search]
  # @return [Hash] the products JSON with its meta
  def search_json(search)
    products, next_cursor, match = search.page(after: params[:after], limit: page_limit)
    { products: products.map { |product| product_json(product) }, meta: { next_cursor:, match: } }
  end
end
