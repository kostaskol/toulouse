module V1
  module Storefront
    class CategoryProductsController < BaseController
      include Paginates
      include CatalogJson
      include FiltersProducts

      def index
        category = Category.find_by!(slug: params[:category_slug])
        products = catalog.where(category_id: category.subtree_ids)
        filter = product_filter
        page, next_cursor = paginate(filter.apply(products))
        render json: filtered_json(page, { next_cursor: }) { filter.facets(products, root: category) }
      end
    end
  end
end
