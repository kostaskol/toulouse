# A fact a tenant's products can state, such as screen size. Variants of a product differ by its selectable specs.
class Specification < ApplicationRecord
  include Tenancy::Scoped

  has_paper_trail versions: { class_name: "Version" }

  # Destroyed one by one, so the audit log records each removal.
  has_many :values, class_name: "Product::SpecificationValue", dependent: :destroy
  has_many :images, class_name: "Product::Image", inverse_of: :specification
  has_many :category_links, class_name: "Category::SpecificationLink", inverse_of: :specification, dependent: :destroy

  # Prefixed, because `all` would replace the scope every model has.
  enum :mode, { any: 0, all: 1 }, prefix: true, validate: true
  # Comparison feeds read the kind. Size is for clothing and footwear only, as Skroutz forbids dimensions there.
  enum :kind, { none: 0, colour: 1, size: 2 }, prefix: true, validate: true

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true
  validates :position, numericality: { only_integer: true }
  validate :key_unique
  validate :flags_agree
  validate :single_values_kept, on: :update, if: -> { multiple_changed?(to: false) }
  validate :variants_kept, on: :update, if: -> { kind_changed? || selectable_changed? }

  before_validation { self.key = self.class.fold([name.to_s]).first if name_changed? }
  # Before the values go, so their products are known.
  before_destroy(prepend: true) { @product_ids = values.distinct.pluck(:product_id) }
  before_destroy :unlink_images
  after_destroy_commit { ProductSearchRefreshJob.perform_later(@product_ids) if @product_ids.any? }
  after_update :unlink_images, if: -> { saved_change_to_selectable?(to: false) }

  # Folds names as facets key them.
  #
  # @param names [Array<String>]
  # @return [Array<String>]
  def self.fold(names)
    return [] if names.empty?

    connection.select_values(sanitize_sql([<<~SQL, names.map(&:strip)]))
      SELECT #{Product::Filter.fold_sql("name")} FROM unnest(ARRAY[?]::text[]) WITH ORDINALITY AS names(name, n)
      ORDER BY n
    SQL
  end

  # Finds the definition for each name by folded name, and creates the missing ones.
  #
  # @param names [Array<String>]
  # @return [Hash{String => Specification}]
  def self.resolve(names)
    keys = fold(names)
    found = where(key: keys).index_by(&:key)
    names.zip(keys).to_h do |name, key|
      [name, found[key] ||= create_or_find_by!(key:) { |specification| specification.name = name }]
    end
  end

  private

  def key_unique
    errors.add(:name, :taken) if key && self.class.where(key:).where.not(id:).exists?
  end

  def flags_agree
    errors.add(:selectable, :required_by_kind) unless kind_none? || selectable
    errors.add(:multiple, :off_when_selectable) if selectable && multiple
    errors.add(:mode, :any_when_single) if mode_all? && !multiple
  end

  def single_values_kept
    held = values.group(:product_id, :variant_id).having("count(*) > 1").exists?
    errors.add(:multiple, :multiple_values_held) if held
  end

  # Refused here, because the products it breaks could not be saved again.
  def variants_kept
    definitions = self.class.where.not(id:).index_by(&:key).merge(key => self)
    faults = Product.where(id: values.select(:product_id)).find_each.flat_map do |product|
      Product::Selection.new(product, definitions:).faults
    end
    errors.add(:kind, :kind_in_use) if faults.include?(:kind_taken)
    errors.add(:selectable, :selection_in_use) if faults.intersect?([:duplicate_combination, :selection_incomplete])
  end

  # Audited one by one, like the values.
  def unlink_images = images.each { |image| image.update!(specification: nil, value: nil) }
end
