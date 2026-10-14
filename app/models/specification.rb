# A fact a tenant's products can state, such as screen size. Unlike an option, the shopper does not pick it.
class Specification < ApplicationRecord
  include Tenancy::Scoped

  has_paper_trail versions: { class_name: "Version" }

  # Destroyed one by one, so the audit log records each removal.
  has_many :values, class_name: "Product::SpecificationValue", dependent: :destroy

  # Prefixed, because `all` would replace the scope every model has.
  enum :mode, { any: 0, all: 1 }, prefix: true, validate: true

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true
  validates :position, numericality: { only_integer: true }
  validate :key_unique

  before_validation { self.key = self.class.fold([name.to_s]).first if name_changed? }
  # Before the values go, so their products are known.
  before_destroy(prepend: true) { @product_ids = values.distinct.pluck(:product_id) }
  after_destroy_commit { ProductSearchRefreshJob.perform_later(@product_ids) if @product_ids.any? }

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
end
