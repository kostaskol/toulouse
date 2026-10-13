module ProductImageJson
  private

  def image_json(image)
    file = image.file
    signed_id = file.blob.signed_id
    {
      id: image.id,
      alt: image.alt || image.product.title,
      width: file.metadata[:width],
      height: file.metadata[:height],
      url: media_url_for(file.variant(:original), signed_id),
      sizes: Product::Image::WIDTHS.map do |width|
        { width:, url: media_url_for(file.variant(:"w#{width}"), signed_id) }
      end
    }
  end

  # The request host is the BFF's internal name for the API, which no browser can reach.
  def media_url_for(variant, signed_id)
    origin = Rails.configuration.x.media_origin.presence || raise(KeyError, "MEDIA_ORIGIN is not set")
    origin + media_path(signed_id, variant.variation.key, variant.filename)
  end
end
