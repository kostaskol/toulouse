module V1
  module Storefront
    class CartsController < BaseController
      include CartJson

      def show
        render_cart(current_cart)
      end
    end
  end
end
