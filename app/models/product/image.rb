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
  # A link to one selectable spec value. With none, the image shows on every variant.
  belongs_to :specification, optional: true, inverse_of: :images

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
  validate :link_valid

  before_create { self.position = product.images.maximum(:position).to_i + 1 }

  # @return [Hash{String => String}] the linked spec name with its value, or empty
  def selection = specification ? { specification.name => value } : {}

  # @param selection [Hash{String => String}, nil] one spec name with its value, or none to show on every variant
  def selection=(selection)
    selection = selection.to_h if selection.respond_to?(:permitted?)
    name, value = selection.first if selection.is_a?(Hash) && selection.one?
    found = Specification.find_by(key: Specification.fold([name]).first) if name.is_a?(String) && value.is_a?(String)
    @selection_invalid = selection.present? && found.nil?
    self.specification = found
    self.value = found && value.strip
  end

  # Old shops keep Greek letters and spaces in file names, which URI refuses unless encoded.
  #
  # @param url [String]
  # @return [String]
  def self.encode_url(url) = url.gsub(/[^\x21-\x7E]+/) { |part| ERB::Util.url_encode(part) }

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

  def link_valid
    return errors.add(:selection, :invalid) if @selection_invalid
    return unless specification && (specification_id_changed? || value_changed?)

    used = Product::SpecificationValue.exists?(product_id:, specification:, value:)
    errors.add(:selection, :invalid) unless specification.selectable && used
  end

  def within_limit
    errors.add(:base, :too_many_images, count: MAX_PER_PRODUCT) if product.images.count >= MAX_PER_PRODUCT
  end
end
