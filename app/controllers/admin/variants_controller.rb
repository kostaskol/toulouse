module Admin
  class VariantsController < BaseController
    include CatalogJson

    allow_any_staff

    FIELDS = [
      :sku, :barcode, :mpn, :price_cents, :compare_at_price_cents, :vat_class, :status, :track_stock, :allow_oversell,
      :image_id, { option_values: {} }
    ].freeze

    def create
      variant = Product.find(params[:product_id]).variants.create!(variant_params)
      render status: :created, json: { variant: variant_json(variant) }
    end

    def update
      variant = Product.find(params[:product_id]).variants.find(params[:id])
      variant.update!(variant_params)
      render json: { variant: variant_json(variant) }
    end

    private

    def variant_params = params.permit(*FIELDS)
  end
end
