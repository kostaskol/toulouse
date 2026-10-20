module V1
  module Storefront
    module CartJson
      include ProductImageJson

      LINE_PRELOADS = {
        variant: [
          { specification_values: :specification },
          { product: [{ specification_values: :specification },
                      { images: [:specification, { file_attachment: :blob }] }] }
        ]
      }.freeze

      private

      # A signed-in shopper's cart, or the guest cart the BFF's token opens.
      #
      # @return [Cart, nil]
      def current_cart
        return Cart.find_by(shopper: shopper_session.shopper) if shopper_session

        Cart.for_guest(request.headers[BaseController::CART_TOKEN_HEADER])
      end

      # @param cart [Cart, nil] nil reads as an empty cart
      # @param warnings [Array<BaseController::Warning, nil, false>]
      def render_cart(cart, *warnings)
        lines = cart ? cart.lines.preload(LINE_PRELOADS).to_a : []
        json = {
          lines: lines.map { |line| line_json(line) },
          subtotal_cents: lines.sum { |line| line.variant.price_cents * line.buyable_quantity },
          line_count: lines.size
        }
        render json: { cart: json, **warnings_json(*warnings) }
      end

      def line_json(line)
        variant = line.variant
        product = variant.product
        selection = variant.selection
        state = line.state

        json = {
          variant_id: variant.id,
          product: { title: product.title, slug: product.slug },
          selection:,
          image: line_image(product, selection)&.then { |image| image_json(image) },
          price_cents: variant.price_cents,
          pre_discount_price_cents: variant.pre_discount_price_cents,
          quantity: line.quantity,
          total_cents: variant.price_cents * line.quantity,
          state:
        }
        json[:available_quantity] = line.quantity_limit if state == "over_stock"
        json
      end

      # An image linked to one of the variant's values first, then one shown on every variant.
      def line_image(product, selection)
        linked, shared = product.images.partition(&:specification)
        linked.find { |image| image.selection <= selection } || shared.first
      end
    end
  end
end
