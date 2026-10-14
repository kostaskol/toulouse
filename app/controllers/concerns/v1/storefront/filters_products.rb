module V1
  module Storefront
    module FiltersProducts
      extend ActiveSupport::Concern
      include RendersFailures

      FAILURE = Failure.new(
        status: :unprocessable_content,
        code: "invalid_filter",
        message: "The filter must use the keys and value types the facets describe, with price_min at most price_max."
      )

      included do
        rescue_from(Product::Filter::Invalid) { |error| render_failure(FAILURE, field: error.field) }
      end

      private

      def product_filter
        filter = params[:filter]
        Product::Filter.new(filter.respond_to?(:to_unsafe_h) ? filter.to_unsafe_h.to_hash : filter)
      end

      # @param products [Array<Product>] the page
      # @param meta [Hash]
      # @param facets [Proc] builds the facets, called on the first page only
      # @return [Hash]
      def filtered_json(products, meta, &facets)
        json = { products: products.map { |product| product_json(product) } }
        json[:facets] = facets.call unless params[:after]
        json.merge(meta:)
      end
    end
  end
end
