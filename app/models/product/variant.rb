class Product::Variant < ApplicationRecord
  include Tenancy::Scoped

  MAX_PER_PRODUCT = 100

  has_paper_trail versions: { class_name: "Version" }

  belongs_to :product, inverse_of: :variants

  enum :vat_class, { standard: 0, reduced: 1, super_reduced: 2 }, validate: true
  enum :status, { active: 0, archived: 1 }, validate: true

  normalizes :sku, with: ->(sku) { sku.strip.presence }

  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :compare_at_price_cents, numericality: { only_integer: true, greater_than: :price_cents },
                                     allow_nil: true, if: :price_cents
  validates :sku, uniqueness: { scope: :tenant_id }, allow_nil: true
  validate :option_values_match_product
  validate :combination_unique
  validate :within_limit, on: :create
  validate :keeps_published_product_sellable

  private

  # Read from memory, so a product saved with its variants sees the unsaved ones.
  def siblings
    product.variants.reject { |variant| variant.equal?(self) || (persisted? && variant.id == id) }
  end

  def option_values_match_product
    return if option_values.is_a?(Hash) && option_values.keys.sort == product.option_names.sort &&
              option_values.values.all? { |value| value.is_a?(String) && value.present? }

    errors.add(:option_values, :invalid)
  end

  def combination_unique
    return unless siblings.any? { |variant| variant.option_values == option_values }

    errors.add(:option_values, :duplicate_combination)
  end

  def within_limit
    errors.add(:base, :too_many_variants, count: MAX_PER_PRODUCT) if siblings.size >= MAX_PER_PRODUCT
  end

  def keeps_published_product_sellable
    return unless product.published? && status_changed?(to: "archived") && siblings.none?(&:active?)

    errors.add(:status, :last_active_variant)
  end
end
