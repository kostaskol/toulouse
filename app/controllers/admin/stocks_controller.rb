module Admin
  class StocksController < BaseController
    include CatalogJson

    allow_any_staff

    FAILURES = {
      invalid_stock_change: Failure.new(
        status: :unprocessable_content,
        code: "invalid_stock_change",
        message: "Send either quantity, to set the counted stock, or an integer delta, to add to it."
      )
    }.freeze

    def update
      variant = Product.find(params[:product_id]).variants.find(params[:variant_id])
      change = params.permit(:quantity, :delta, :reason)
      quantity_only = !change[:quantity].nil? && !change.key?(:delta)
      # Through a decimal string, so a float is refused rather than truncated and "010" means ten.
      delta = Integer(change[:delta].to_s, 10, exception: false) unless change.key?(:quantity)
      return render_failure(FAILURES.fetch(:invalid_stock_change)) unless quantity_only || delta

      variant.change_stock!(quantity: change[:quantity], delta:, reason: change[:reason])
      render json: { variant: variant_json(variant) }
    end
  end
end
