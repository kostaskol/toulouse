class Product < ApplicationRecord
  include Tenancy::Scoped
  include Sluggable
  include HasSpecifications

  MAX_OPTIONS = 3

  # The search columns are derived, so versions leave them out.
  has_paper_trail versions: { class_name: "Version" }, skip: [:search_document, :search_text]

  belongs_to :brand, optional: true
  # Optional here, so a missing or unknown id fails as category_id, the field a client sends.
  belongs_to :category, optional: true
  has_many :variants, -> { order(:id) }, inverse_of: :product, index_errors: true
  has_many :active_variants, -> { active.order(:id) }, class_name: "Product::Variant"
  has_many :images, -> { order(:position, :id) }, inverse_of: :product
  # The product's own values. A variant's overrides sit on the variant.
  has_many :specification_values, -> { where(variant_id: nil) }, class_name: "Product::SpecificationValue",
           autosave: true

  accepts_nested_attributes_for :variants

  scope :with_images, -> { includes(images: { file_attachment: :blob }) }
  scope :with_specifications, lambda { |variants: :variants|
    includes(specification_values: :specification, variants => { specification_values: :specification })
  }

  enum :status, { draft: 0, published: 1, archived: 2 }, validate: true

  validates :title, presence: true
  validates :variants, presence: true, on: :create
  validates :option_names, length: { maximum: MAX_OPTIONS }
  validate :option_names_distinct
  validate :brand_in_tenant
  validate :active_variant_when_published
  validate :category_in_tenant

  around_save :refresh_search

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

  # True while the product saves, variants included.
  def saving? = @saving

  private

  def slug_source = title

  def refresh_search
    @saving = true
    yield
    Product::Search.refresh(self)
  ensure
    @saving = false
  end

  def option_names_distinct
    named = option_names.all? { |name| name.is_a?(String) && name.present? }
    errors.add(:option_names, :invalid) unless named && option_names.uniq.size == option_names.size
  end

  # Read before the uuid cast, which turns a malformed id into nil.
  def brand_in_tenant
    errors.add(:brand_id, :invalid) if brand_id_before_type_cast.present? && brand.nil?
  end

  # Read before the uuid cast, which turns a malformed id into nil.
  def category_in_tenant
    errors.add(:category_id, category_id_before_type_cast.present? ? :invalid : :blank) if category.nil?
  end

  def active_variant_when_published
    errors.add(:status, :no_active_variant) if published? && variants.none?(&:active?)
  end
end
