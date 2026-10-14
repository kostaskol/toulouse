module V1
  module Storefront
    class CategoryProductsController < BaseController
      include Paginates
      include CatalogJson
      include FiltersProducts

      def index
        category = Category.find_by!(slug: params[:category_slug])
        linked = Product::Categorization.where(category_id: category.subtree_ids).select(:product_id)
        products = catalog.where(id: linked)
        filter = product_filter
        page, next_cursor = paginate(filter.apply(products))
        render json: filtered_json(page, { next_cursor: }) { filter.facets(products, root: category) }
      end
    end
  end
end
