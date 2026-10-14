class Category < ApplicationRecord
  include Tenancy::Scoped
  include Sluggable

  has_paper_trail versions: { class_name: "Version" }

  belongs_to :parent, class_name: "Category", optional: true
  # Before the links, so a refused delete leaves them in place.
  has_many :children, class_name: "Category", foreign_key: :parent_id, inverse_of: :parent,
                      dependent: :restrict_with_error
  has_many :categorizations, class_name: "Product::Categorization", dependent: :destroy

  validates :name, presence: true
  validates :position, numericality: { only_integer: true }
  validate :parent_in_tenant
  validate :parent_outside_subtree, if: -> { persisted? && parent_id_changed? }

  # Before the links go, so their products are known.
  before_destroy(prepend: true) { @product_ids = categorizations.pluck(:product_id) }
  after_update_commit :refresh_product_search, if: -> { saved_change_to_name? || saved_change_to_parent_id? }
  after_destroy_commit { ProductSearchRefreshJob.perform_later(@product_ids) if @product_ids.any? }

  # @return [Hash{String, nil => Array<Category>}] siblings in menu order, keyed by parent id
  def self.by_parent
    order(:position, :id).group_by(&:parent_id)
  end

  # @return [Array<String>] this category's id and the ids of every category below it
  def subtree_ids
    # UNION rather than UNION ALL, so two concurrent moves that form a loop still end.
    self.class.connection.select_values(self.class.sanitize_sql([<<~SQL, id]))
      WITH RECURSIVE subtree(id) AS (
        SELECT ?::uuid
        UNION
        SELECT categories.id FROM categories JOIN subtree ON categories.parent_id = subtree.id
      )
      SELECT id FROM subtree
    SQL
  end

  # The one category whose name means the same words, ignoring accents, case and inflection, or reads the same
  # in greeklish.
  #
  # @param terms [Array<String>]
  # @return [Category, nil] nil when none or several match
  def self.named(terms)
    return if terms.empty?

    same_words = "strip(to_tsvector('search', name)) = strip(to_tsvector('search', ?))"
    matches = where(same_words, terms.join(" ")).to_a
    if terms.any? { |term| Greeklish.latin?(term) }
      skeleton = terms.map { |term| Greeklish.skeleton(term) }
      # Tens to hundreds of categories per tenant, so they are compared in memory.
      matches |= all.select do |category|
        category.name.scan(Product::Search::WORD).map { |word| Greeklish.skeleton(word) } == skeleton
      end
    end
    matches.first if matches.size == 1
  end

  # @param ids [Array<String>]
  # @return [Array<String>] the names of these categories and of every category above them
  def self.names_with_ancestors(ids)
    connection.select_values(sanitize_sql([<<~SQL, ids]))
      WITH RECURSIVE ancestors(id, parent_id, name) AS (
        SELECT id, parent_id, name FROM categories WHERE id IN (?)
        UNION
        SELECT categories.id, categories.parent_id, categories.name
        FROM categories JOIN ancestors ON categories.id = ancestors.parent_id
      )
      SELECT name FROM ancestors
    SQL
  end

  private

  def slug_source = name

  # A product's document holds the names of its categories' ancestors too, so the whole subtree changes.
  def refresh_product_search
    ids = Product::Categorization.where(category_id: subtree_ids).distinct.pluck(:product_id)
    ProductSearchRefreshJob.perform_later(ids) if ids.any?
  end

  # Read before the uuid cast, which turns a malformed id into nil.
  def parent_in_tenant
    errors.add(:parent_id, :invalid) if parent_id_before_type_cast.present? && parent.nil?
  end

  def parent_outside_subtree
    errors.add(:parent_id, :invalid_parent) if parent_id && subtree_ids.include?(parent_id)
  end
end
