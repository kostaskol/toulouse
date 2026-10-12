module Admin
  class ProductsController < BaseController
    include Paginates
    include CatalogJson

    allow_any_staff

    FIELDS = [:title, :slug, :description, :status, :brand_id].freeze

    def index
      scope = Product.includes(:brand, :variants)
      scope = scope.where(status: params[:status]) if params[:status]
      scope = scope.where(brand: Brand.find(params[:brand_id])) if params[:brand_id]
      products, next_cursor = paginate(scope)
      render json: { products: products.map { |product| product_json(product) }, meta: { next_cursor: } }
    end

    def show
      render json: { product: product_json(Product.find(params[:id])) }
    end

    def create
      variants = params.permit(variants: VariantsController::FIELDS).fetch(:variants, [])
      product = Product.create!(params.permit(*FIELDS, option_names: []).merge(variants_attributes: variants))
      render status: :created, json: { product: product_json(product) }
    end

    def update
      product = Product.find(params[:id])
      product.update!(params.permit(*FIELDS))
      render json: { product: product_json(product) }
    end
  end
end
