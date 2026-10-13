class Product < ApplicationRecord
  include Tenancy::Scoped
  include Sluggable

  MAX_OPTIONS = 3

  has_paper_trail versions: { class_name: "Version" }

  belongs_to :brand, optional: true
  has_many :variants, -> { order(:id) }, inverse_of: :product, index_errors: true
  has_many :active_variants, -> { active.order(:id) }, class_name: "Product::Variant"
  has_many :images, -> { order(:position, :id) }, inverse_of: :product
  has_many :categorizations, dependent: :destroy
  # Destroys the links one by one, so the audit log records each removal.
  has_many :categories, through: :categorizations, dependent: :destroy

  accepts_nested_attributes_for :variants

  scope :with_images, -> { includes(images: { file_attachment: :blob }) }

  enum :status, { draft: 0, published: 1, archived: 2 }, validate: true

  validates :title, presence: true
  validates :variants, presence: true, on: :create
  validates :option_names, length: { maximum: MAX_OPTIONS }
  validate :option_names_distinct
  validate :brand_in_tenant
  validate :active_variant_when_published
  validate :categories_in_tenant

  # Renames, reorders, adds and removes options, and rewrites every variant to match.
  #
  # @param options [Array<Hash>] in display order. `from` keeps an existing
  #   option under `name`; otherwise `value` adds `name` to every variant.
  #   Options left out are removed.
  def update_options!(options)
    renames = options.select { |option| option[:from] }.to_h { |option| [option[:from], option[:name]] }
    added = options.reject { |option| option[:from] }.to_h { |option| [option[:name], option[:value]] }

    errors.add(:option_names, :invalid) unless (renames.keys - option_names).empty?
    raise ActiveRecord::RecordInvalid, self if errors.any?

    self.option_names = options.map { |option| option[:name] }
    variants.each do |variant|
      variant.option_values = variant.option_values.slice(*renames.keys).transform_keys(renames).merge(added)
    end
    save!
  end

  # Stores an uploaded image as the product's last.
  #
  # @param io [IO] the raw upload
  # @return [Product::Image]
  def add_image!(io)
    Tempfile.create(binmode: true) do |file|
      # One byte over the cap is enough for validation to refuse it.
      IO.copy_stream(io, file, Product::Image::MAX_BYTES + 1)
      file.rewind
      image = Product::Image.new(product: self, file: Product::Image.attachable(file, slug))
      # Locked, so two uploads cannot both take the last slot.
      with_lock { image.save! }
      image
    rescue StandardError
      # The file goes to storage after commit. A failed upload must not leave a row with no file.
      image.destroy! if image&.persisted?
      raise
    end
  end

  # Sets the display order of the product's images.
  #
  # @param ids [Array<String>] every image id, in display order
  def order_images!(ids)
    ids = Array(ids).map { |id| id.to_s.downcase }
    unless ids.sort == images.map(&:id).sort
      errors.add(:image_ids, :invalid)
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      images.each { |image| image.update!(position: ids.index(image.id)) }
    end
  end

  # Replaces the product's categories. An id outside the tenant fails validation.
  #
  # @param ids [Array<String>]
  def category_ids=(ids)
    @unknown_category_ids = false
    super(Array(ids).uniq { |id| id.to_s.downcase })
  rescue ActiveRecord::RecordNotFound
    @unknown_category_ids = true
  end

  private

  def slug_source = title

  def option_names_distinct
    named = option_names.all? { |name| name.is_a?(String) && name.present? }
    errors.add(:option_names, :invalid) unless named && option_names.uniq.size == option_names.size
  end

  # Read before the uuid cast, which turns a malformed id into nil.
  def brand_in_tenant
    errors.add(:brand_id, :invalid) if brand_id_before_type_cast.present? && brand.nil?
  end

  def categories_in_tenant
    errors.add(:category_ids, :invalid) if @unknown_category_ids
  end

  def active_variant_when_published
    errors.add(:status, :no_active_variant) if published? && variants.none?(&:active?)
  end
end
