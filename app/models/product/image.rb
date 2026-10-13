class Product::Image < ApplicationRecord
  include Tenancy::Scoped

  MAX_PER_PRODUCT = 50
  MAX_BYTES = 20.megabytes
  MAX_PIXELS = 100_000_000
  WIDTHS = [200, 600, 1200].freeze
  # Keyed by the libvips loader, which reads the bytes rather than the name.
  FORMATS = {
    "jpegload" => { content_type: "image/jpeg", extension: "jpg" },
    "pngload" => { content_type: "image/png", extension: "png" },
    "webpload" => { content_type: "image/webp", extension: "webp" }
  }.freeze
  CONTENT_TYPES = FORMATS.values.pluck(:content_type).freeze

  # Not on touch: Active Storage touches the row on attach, which is no edit.
  has_paper_trail versions: { class_name: "Version" }, on: %i[create update destroy]

  belongs_to :product, inverse_of: :images

  # Strips metadata on every copy, because phone photos carry GPS in EXIF.
  has_one_attached :file do |file|
    file.variant :original, saver: { strip: true }, preprocessed: true
    WIDTHS.each do |width|
      file.variant :"w#{width}", resize_to_limit: [width, nil], format: :webp, saver: { strip: true },
                                 preprocessed: true
    end
  end

  normalizes :alt, with: ->(alt) { alt.strip.presence }

  validates :file, presence: true
  validate :file_acceptable, if: -> { file.attached? && file.blob.new_record? }
  validate :within_limit, on: :create

  before_create { self.position = product.images.maximum(:position).to_i + 1 }

  # Builds the attachable for an uploaded file. libvips reads the type and size
  # from the header alone, so nothing decodes before validation checks the
  # limits.
  #
  # @param file [File]
  # @param name [String] the filename without its extension
  # @return [Hash]
  def self.attachable(file, name)
    {
      io: file, identify: false,
      key: "#{Tenancy.current_tenant_id!}/#{ActiveStorage::Blob.generate_unique_secure_token}",
      **header(file.path, name)
    }
  end

  def self.header(path, name)
    image = Vips::Image.new_from_file(path)
    format = FORMATS.fetch(image.get("vips-loader"))
    upright = image.autorot
    {
      filename: "#{name}.#{format[:extension]}", content_type: format[:content_type],
      # Analyzed here, because the analyzer job would touch this row with no tenant set.
      metadata: { width: upright.width, height: upright.height, analyzed: true }
    }
  rescue Vips::Error, KeyError
    { filename: name, content_type: "application/octet-stream" }
  end
  private_class_method :header

  private

  def file_acceptable
    blob = file.blob
    return errors.add(:file, :too_large, count: MAX_BYTES / 1.megabyte) if blob.byte_size > MAX_BYTES
    return errors.add(:file, :content_type) unless CONTENT_TYPES.include?(blob.content_type)

    pixels = blob.metadata[:width] * blob.metadata[:height]
    errors.add(:file, :too_many_pixels, count: MAX_PIXELS / 1_000_000) if pixels > MAX_PIXELS
  end

  def within_limit
    errors.add(:base, :too_many_images, count: MAX_PER_PRODUCT) if product.images.count >= MAX_PER_PRODUCT
  end
end
