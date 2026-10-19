class Product::Variant < ApplicationRecord
  include Tenancy::Scoped
  include HasSpecifications

  MAX_PER_PRODUCT = 100
  # The price and stock columns are 4-byte integers.
  MAX_INTEGER = (2**31) - 1

  has_paper_trail versions: { class_name: "Version" }, meta: { reason: :stock_reason }

  attr_accessor :stock_reason

  belongs_to :product, inverse_of: :variants
  # Overrides only. The product states the rest.
  has_many :specification_values, class_name: "Product::SpecificationValue", inverse_of: :variant, autosave: true

  enum :vat_class, { standard: 0, reduced: 1, super_reduced: 2 }, validate: true
  enum :status, { active: 0, archived: 1 }, validate: true

  normalizes :sku, with: ->(sku) { sku.strip.presence }

  validates :price_cents, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_INTEGER
  }
  validates :pre_discount_price_cents, numericality: {
    only_integer: true, greater_than: :price_cents, less_than_or_equal_to: MAX_INTEGER
  }, allow_nil: true, if: :price_cents
  validates :sku, uniqueness: { scope: :tenant_id }, allow_nil: true
  validates :stock_quantity, numericality: { only_integer: true, less_than_or_equal_to: MAX_INTEGER }
  validate :stock_covered
  validate :sku_unique_among_siblings
  validate :within_limit, on: :create
  validate :keeps_published_product_sellable
  validate :selection_valid, if: -> { !product.saving? && (new_record? || @specifications || status_changed?) }

  after_save :refresh_product_search, if: -> { saved_change_to_status? || saved_change_to_specifications? }
  after_save(if: -> { saved_change_to_specifications? && !product.saving? }) { product.unlink_stale_images }

  scope :available, -> { where(track_stock: false).or(where(allow_oversell: true)).or(where(stock_quantity: 1..)) }

  def available?
    !track_stock || allow_oversell || stock_quantity.positive?
  end

  # @return [Hash{String => String}] the value of each selectable spec by name, in definition order. An override
  #   wins over the product's value.
  def selection
    entries = product.specification_entries.to_h.merge(specification_entries.to_h)
    entries.select { |specification, _| specification.selectable }
           .sort_by { |specification, _| [specification.position, specification.id] }
           .to_h { |specification, values| [specification.name, values.first] }
  end

  # Read from memory, so a product saved with its variants sees the unsaved ones.
  #
  # @return [Array<Product::Variant>] the product's other variants
  def siblings
    product.variants.reject { |variant| variant.equal?(self) || (persisted? && variant.id == id) }
  end

  # Sets the counted stock, or adds a delta to the current stock under a row
  # lock, so a sale written in between is kept.
  #
  # @param quantity [Integer, nil] nil to apply the delta instead
  # @param delta [Integer, nil]
  # @param reason [String, nil]
  def change_stock!(quantity: nil, delta: nil, reason: nil)
    with_lock do
      self.stock_quantity = quantity.nil? ? stock_quantity + delta : quantity
      self.stock_reason = reason
      save!
    end
  end

  private

  def refresh_product_search
    Product::Search.refresh(product) unless product.saving?
  end

  def selection_valid
    Product::Selection.new(product, variant: self).faults.each { |fault| errors.add(:specifications, fault) }
  end

  def stock_covered
    return unless track_stock && !allow_oversell && stock_quantity.is_a?(Integer) && stock_quantity.negative?

    errors.add(:stock_quantity, :insufficient_stock)
  end

  # A database lookup cannot see siblings that are saved in the same nested create.
  def sku_unique_among_siblings
    return if sku.nil? || errors.of_kind?(:sku, :taken) || siblings.none? { |variant| variant.sku == sku }

    errors.add(:sku, :taken)
  end

  def within_limit
    errors.add(:base, :too_many_variants, count: MAX_PER_PRODUCT) if siblings.size >= MAX_PER_PRODUCT
  end

  def keeps_published_product_sellable
    return unless product.published? && status_changed?(to: "archived") && siblings.none?(&:active?)

    errors.add(:status, :last_active_variant)
  end
end
