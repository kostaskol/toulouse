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

  private

  def slug_source = name

  # Read before the uuid cast, which turns a malformed id into nil.
  def parent_in_tenant
    errors.add(:parent_id, :invalid) if parent_id_before_type_cast.present? && parent.nil?
  end

  def parent_outside_subtree
    errors.add(:parent_id, :invalid_parent) if parent_id && subtree_ids.include?(parent_id)
  end
end
