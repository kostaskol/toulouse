module Admin
  class BrandsController < BaseController
    include Paginates
    include CatalogJson

    allow_any_staff

    FAILURES = {
      brand_in_use: Failure.new(
        status: :unprocessable_content,
        code: "brand_in_use",
        message: "Products still use this brand. Move them to another brand first."
      )
    }.freeze

    def index
      brands, next_cursor = paginate(Brand.all)
      render json: { brands: brands.map { |brand| brand_json(brand) }, meta: { next_cursor: } }
    end

    def create
      brand = Brand.create!(brand_params)
      render status: :created, json: { brand: brand_json(brand) }
    end

    def update
      brand = Brand.find(params[:id])
      brand.update!(brand_params)
      render json: { brand: brand_json(brand) }
    end

    def destroy
      return head :no_content if Brand.find(params[:id]).destroy

      render_failure(FAILURES.fetch(:brand_in_use))
    end

    private

    def brand_params = params.permit(:name, :slug)
  end
end
