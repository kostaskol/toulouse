class Product < ApplicationRecord
  include Tenancy::Scoped
  include Sluggable
  include HasSpecifications

  # The search columns are derived, so versions leave them out.
  has_paper_trail versions: { class_name: "Version" }, skip: [:search_document, :search_text]

  belongs_to :brand, optional: true
  # Optional here, so a missing or unknown id fails as category_id, the field a client sends.
  belongs_to :category, optional: true
  has_many :variants, -> { order(:id) }, inverse_of: :product, index_errors: true
  has_many :active_variants, -> { active.order(:id) }, class_name: "Product::Variant", inverse_of: :product
  has_many :images, -> { order(:position, :id) }, inverse_of: :product
  # The product's own values. A variant's overrides sit on the variant.
  has_many :specification_values, -> { where(variant_id: nil) }, class_name: "Product::SpecificationValue",
           autosave: true

  accepts_nested_attributes_for :variants

  scope :with_images, -> { includes(images: [:specification, { file_attachment: :blob }]) }
  scope :with_specifications, lambda { |variants: :variants|
    includes(specification_values: :specification, variants => { specification_values: :specification })
  }

  enum :status, { draft: 0, published: 1, archived: 2 }, validate: true

  validates :title, presence: true
  validates :variants, presence: true, on: :create
  validate :brand_in_tenant
  validate :active_variant_when_published
  validate :category_in_tenant
  validate :selection_valid
  # After the selection check, which preloads the variants' values.
  validate :required_specifications_present, if: -> { status_changed?(to: "published") }

  around_save :refresh_search
  # After the nested variants save, so it runs once for all of them.
  after_save :unlink_stale_images, if: lambda {
    saved_change_to_specifications? || (variants.loaded? && variants.any?(&:saved_change_to_specifications?))
  }

  # Shares each image whose linked value no product or variant holds any more, so it still shows somewhere.
  def unlink_stale_images
    held = Product::SpecificationValue.where(product_id: id).pluck(:specification_id, :value)
    images.where.not(specification_id: nil).each do |image|
      # One by one, so the audit log records each.
      image.update!(specification: nil, value: nil) unless held.include?([image.specification_id, image.value])
    end
  end

  # Stores an uploaded image as the product's last.
  #
  # @param io [IO] the raw upload
  # @param selection [Hash{String => String}, nil] the selectable spec value it shows for, or none for every variant
  # @return [Product::Image]
  def add_image!(io, selection = nil)
    Tempfile.create(binmode: true) do |file|
      # One byte over the cap is enough for validation to refuse it.
      IO.copy_stream(io, file, Product::Image::MAX_BYTES + 1)
      file.rewind
      image = Product::Image.new(product: self, file: Product::Image.attachable(file, slug), selection:)
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

  # @return [Array<Specification>] the specs its category or one above it requires that an active variant lacks
  def missing_specifications
    return [] unless category

    effective = effective_specifications(variants.select(&:active?)).values
    category.required_specifications.reject do |specification|
      effective.all? { |values| values.key?(specification.key) }
    end
  end

  # @param variants [Array<Product::Variant>]
  # @return [Hash{Product::Variant => Hash{String => Array<String>}}] each variant's values by definition key. An
  #   override wins over the product's value. Unsaved writes count.
  def effective_specifications(variants)
    own = keyed_specifications
    variants.to_h { |variant| [variant, own.merge(variant.keyed_specifications)] }
  end

  # Its variants skip their own selection check, since the product judges them all at once.
  def valid?(context = nil)
    @validating = true
    super
  ensure
    @validating = false
  end

  # True while the product validates or saves, variants included.
  def saving? = @saving || @validating

  private

  def slug_source = title

  def refresh_search
    @saving = true
    yield
    Product::Search.refresh(self)
  ensure
    @saving = false
  end

  # A saved variant's fault shows on the product, as the variant is not the one saving.
  def selection_valid
    selection = Product::Selection.new(self)
    errors.add(:specifications, selection.fault(self)) if selection.fault(self)
    variants.each_with_index do |variant, index|
      fault = selection.fault(variant)
      if fault && variant.new_record?
        errors.import(ActiveModel::Error.new(variant, :specifications, fault),
                      attribute: :"variants[#{index}].specifications")
      elsif fault && !errors.added?(:specifications, fault)
        errors.add(:specifications, fault)
      end
    end
  end

  # Read before the uuid cast, which turns a malformed id into nil.
  def brand_in_tenant
    errors.add(:brand_id, :invalid) if brand_id_before_type_cast.present? && brand.nil?
  end

  # Read before the uuid cast, which turns a malformed id into nil.
  def category_in_tenant
    errors.add(:category_id, category_id_before_type_cast.present? ? :invalid : :blank) if category.nil?
  end

  # Only on the change to published, so a link added later never blocks saving a product that is already live.
  def required_specifications_present
    names = missing_specifications.map(&:name)
    errors.add(:status, :required_specifications_missing, names: names.join(", ")) if names.any?
  end

  def active_variant_when_published
    errors.add(:status, :no_active_variant) if published? && variants.none?(&:active?)
  end
end
