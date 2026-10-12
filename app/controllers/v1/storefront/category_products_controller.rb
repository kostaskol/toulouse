module V1
  module Storefront
    class CategoryProductsController < BaseController
      include Paginates
      include CatalogJson

      def index
        category = Category.find_by!(slug: params[:category_slug])
        linked = Product::Categorization.where(category_id: category.subtree_ids).select(:product_id)
        products, next_cursor = paginate(Product.published.includes(:brand, :active_variants).where(id: linked))
        render json: { products: products.map { |product| product_json(product) }, meta: { next_cursor: } }
      end
    end
  end
end
