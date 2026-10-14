module Admin
  class ProductsController < BaseController
    include SearchesProducts
    include CatalogJson

    allow_any_staff

    FIELDS = [:title, :slug, :description, :status, :brand_id, { category_ids: [] }].freeze

    def index
      scope = Product.with_images.includes(:brand, :variants, :categories)
      scope = scope.where(status: params[:status]) if params[:status]
      scope = scope.where(brand: Brand.find(params[:brand_id])) if params[:brand_id]
      if params[:category_id]
        scope = scope.where(id: Category.find(params[:category_id]).categorizations.select(:product_id))
      end
      return search(scope) if params[:q].present?

      products, next_cursor = paginate(scope)
      render json: { products: products.map { |product| product_json(product) }, meta: { next_cursor: } }
    end

    def show
      render json: { product: product_json(Product.with_images.find(params[:id])) }
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

    private

    def search(scope)
      return if refuse_query(params[:q], field: "q")

      render json: search_json(Product::Search.new(params[:q], products: scope, variants: Product::Variant.all))
    end
  end
end
