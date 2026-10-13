module ImageFiles
  extend self

  # @param extension [String] any format libvips can save
  # @param width [Integer]
  # @param height [Integer]
  # @param orientation [Integer, nil] an EXIF orientation tag
  # @return [String] a blank image's bytes
  def image_bytes(extension = "jpg", width: 1, height: 1, orientation: nil)
    image = Vips::Image.black(width, height)
    image = image.mutate { |copy| copy.set_type!(GObject::GINT_TYPE, "orientation", orientation) } if orientation
    image.write_to_buffer(".#{extension}")
  end

  # Kept open, because Active Storage uploads it after the record commits.
  #
  # @return [Tempfile]
  def image_file(...)
    Tempfile.new(binmode: true).tap do |file|
      file.write(image_bytes(...))
      file.rewind
    end
  end

  # A 1x1 JPEG whose frame header claims the given size.
  #
  # @param width [Integer]
  # @param height [Integer]
  # @return [String]
  def jpeg_claiming(width:, height:)
    bytes = image_bytes
    frame = bytes.index("\xFF\xC0".b)
    bytes[frame + 5, 4] = [height, width].pack("nn")
    bytes
  end
end

RSpec.configure { |config| config.include ImageFiles }
