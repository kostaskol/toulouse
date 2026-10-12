module Admin
  class OptionsController < BaseController
    include CatalogJson

    allow_any_staff

    def update
      product = Product.find(params[:product_id])
      # Checked before permit, which would turn a missing or flat list into "remove every option".
      unless params[:option_names].is_a?(Array) && params[:option_names].all?(ActionController::Parameters)
        product.errors.add(:option_names, :invalid)
        return render_invalid(product)
      end

      product.update_options!(params.permit(option_names: [:name, :from, :value])[:option_names])
      render json: { product: product_json(product) }
    end
  end
end
