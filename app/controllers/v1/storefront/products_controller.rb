module V1
  module Storefront
    class ProductsController < BaseController
      include Paginates
      include CatalogJson

      def index
        products, next_cursor = paginate(catalog)
        render json: { products: products.map { |product| product_json(product) }, meta: { next_cursor: } }
      end

      def show
        render json: { product: product_json(catalog.find_by!(slug: params[:slug])) }
      end

      private

      def catalog = Product.published.includes(:brand, :active_variants)
    end
  end
end
