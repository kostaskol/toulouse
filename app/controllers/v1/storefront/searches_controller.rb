module V1
  module Storefront
    class SearchesController < BaseController
      include SearchesProducts
      include CatalogJson
      include FiltersProducts

      def show
        return if refuse_query(params[:query], field: "query")

        filter = product_filter
        search = Product::Search.new(params[:query], products: catalog, variants: Product::Variant.active)
        # A later page or a filtered one belongs to a product search the shopper is already looking at.
        category = Category.named(search.terms) unless params[:after] || filter.any?
        return render json: { category: category.slice(:id, :name, :slug) } if category

        products, next_cursor, match = search.page(after: params[:after], limit: page_limit, filter:)
        render json: filtered_json(products, { next_cursor:, match: }) { filter.facets(search.matches) }
      end
    end
  end
end
