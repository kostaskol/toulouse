module V1
  module Storefront
    class CartLinesController < BaseController
      include CartJson

      FAILURES = {
        invalid_quantity: Failure.new(
          status: :unprocessable_content,
          code: "invalid_quantity",
          message: "The quantity must be a whole number from 1 to #{Cart::Line::MAX_QUANTITY}."
        ),
        variant_unavailable: Failure.new(
          status: :unprocessable_content,
          code: "variant_unavailable",
          message: "This variant cannot be bought now. It is sold out or no longer sold."
        )
      }.freeze

      QUANTITY_REDUCED = Warning.new(
        code: "quantity_reduced",
        message: "The quantity was lowered to the stock left."
      )

      class Refused < StandardError
        attr_reader :failure, :field

        def initialize(failure, field: nil)
          @failure = failure
          @field = field
          super(failure.message)
        end
      end

      rescue_from(Refused) { |error| render_failure(error.failure, field: error.field) }

      # Checks the request before it finds or creates the cart, so a refused
      # add leaves no empty guest cart behind.
      def create
        variant = sellable_variant(params[:variant_id])
        quantity = requested_quantity
        cart = current_cart || new_cart
        render_change(cart, cart.add!(variant, quantity) && QUANTITY_REDUCED)
      end

      def update
        variant = sellable_variant(params[:variant_id])
        quantity = requested_quantity
        cart = current_cart || raise(ActiveRecord::RecordNotFound)
        render_change(cart, cart.set!(variant, quantity) && QUANTITY_REDUCED)
      end

      def destroy
        cart = current_cart || raise(ActiveRecord::RecordNotFound)
        cart.remove!(params[:variant_id])
        render_change(cart)
      end

      private

      def sellable_variant(id)
        variant = Product::Variant.includes(:product).find_by!(id:)
        variant.sellable? ? variant : raise(Refused, FAILURES.fetch(:variant_unavailable))
      end

      def requested_quantity
        quantity = params[:quantity]
        return quantity if quantity.is_a?(Integer) && quantity.between?(1, Cart::Line::MAX_QUANTITY)

        raise Refused.new(FAILURES.fetch(:invalid_quantity), field: "quantity")
      end

      def new_cart
        return Cart.create_or_find_by!(shopper: shopper_session.shopper) if shopper_session

        Cart.create!
      end

      # Every write moves a guest cart's expiry, so the BFF moves its cookie too.
      # @param warnings [Array<Warning, false>]
      def render_change(cart, *warnings)
        if cart.guest?
          response.set_header(CART_TOKEN_HEADER, cart.token || request.headers[CART_TOKEN_HEADER])
          response.set_header(CART_EXPIRES_HEADER, cart.expires_at.httpdate)
        end
        render_cart(cart, *warnings)
      end
    end
  end
end
