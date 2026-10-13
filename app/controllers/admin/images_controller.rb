module Admin
  class ImagesController < BaseController
    include CatalogJson

    allow_any_staff

    FAILURES = {
      unsupported_media_type: Failure.new(
        status: :unsupported_media_type,
        code: "unsupported_media_type",
        message: "Send the image bytes as #{Product::Image::CONTENT_TYPES.to_sentence(last_word_connector: ' or ')}."
      )
    }.freeze

    # An image body forces a CORS preflight just as JSON does, so the CSRF guard holds.
    skip_before_action :require_json_body!, only: :create
    before_action :require_image_body!, only: :create

    def create
      image = Product.find(params[:product_id]).add_image!(request.body)
      render status: :created, json: { image: image_json(image) }
    end

    def update
      image = find_image
      image.update!(params.permit(:alt))
      render json: { image: image_json(image) }
    end

    def destroy
      find_image.destroy!
      head :no_content
    end

    def order
      product = Product.with_images.find(params[:product_id])
      product.order_images!(params[:image_ids])
      render json: { images: product.images.sort_by(&:position).map { |image| image_json(image) } }
    end

    private

    def find_image = Product.find(params[:product_id]).images.find(params[:id])

    def require_image_body!
      return if Product::Image::CONTENT_TYPES.include?(request.media_type)

      render_failure(FAILURES.fetch(:unsupported_media_type))
    end
  end
end
