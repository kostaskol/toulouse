module V1
  module Storefront
    class SearchesController < BaseController
      include SearchesProducts
      include CatalogJson

      def show
        return if refuse_query(params[:query], field: "query")

        search = Product::Search.new(params[:query], products: catalog, variants: Product::Variant.active)
        # A later page belongs to a product search that already ran.
        category = Category.named(search.terms) unless params[:after]
        return render json: { category: category.slice(:id, :name, :slug) } if category

        render json: search_json(search)
      end
    end
  end
end
