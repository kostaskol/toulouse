class Category < ApplicationRecord
  include Tenancy::Scoped
  include Sluggable

  has_paper_trail versions: { class_name: "Version" }

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, inverse_of: :parent,
                      dependent: :restrict_with_error
  has_many :products, dependent: :restrict_with_error
  has_many :links, -> { order(:id) }, class_name: "Category::SpecificationLink", inverse_of: :category,
                                       dependent: :destroy, autosave: true, validate: false

  validates :name, presence: true
  validates :position, numericality: { only_integer: true }
  validate :parent_in_tenant
  validate :parent_outside_subtree, if: -> { persisted? && parent_id_changed? }
  validate :linked_specifications_exist, if: -> { @linked_specification_ids }

  after_update_commit :refresh_product_search, if: -> { saved_change_to_name? || saved_change_to_parent_id? }

  # @return [Hash{String, nil => Array<Category>}] siblings in menu order, keyed by parent id
  def self.by_parent
    order(:position, :id).group_by(&:parent_id)
  end

  # @return [Array<Hash>] each linked spec's id and whether it is required
  def specification_links = links.map { |link| link.slice(:specification_id, :required) }

  # Replaces every link. A spec left out is unlinked.
  #
  # @param entries [Array<Hash>] each with `specification_id` and `required`
  def specification_links=(entries)
    entries = Array(entries).map { |entry| entry.to_h.symbolize_keys }
    @linked_specification_ids = entries.map { |entry| entry[:specification_id].to_s.downcase }
    # The column casts the flag. Left out means not required.
    wanted = @linked_specification_ids.zip(entries.map { |entry| entry[:required] || false }).to_h
    links.each do |link|
      wanted.key?(link.specification_id) ? link.required = wanted[link.specification_id] : link.mark_for_destruction
    end
    (wanted.keys - links.map(&:specification_id)).each { |id| links.build(specification_id: id, required: wanted[id]) }
  end

  # @return [ActiveRecord::Relation<Specification>] the specs this category or one above it requires
  def required_specifications
    links = SpecificationLink.where(category_id: self.class.with_ancestor_ids([id]), required: true)
    Specification.where(id: links.select(:specification_id)).order(:position, :id)
  end

  # @return [Array<String>] this category's id and the ids of every category below it
  def subtree_ids = self.class.subtree_ids([id])

  # @param ids [Array<String>]
  # @return [Array<String>] these ids and the ids of every category below them
  def self.subtree_ids(ids)
    return [] if ids.empty?

    # UNION rather than UNION ALL, so two concurrent moves that form a loop still end.
    connection.select_values(sanitize_sql([<<~SQL, ids]))
      WITH RECURSIVE subtree(id) AS (
        SELECT unnest(ARRAY[?]::uuid[])
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
  def self.names_with_ancestors(ids) = where(id: with_ancestor_ids(ids)).pluck(:name)

  # @param ids [Array<String>]
  # @return [Array<String>] these ids and the ids of every category above them
  def self.with_ancestor_ids(ids)
    connection.select_values(sanitize_sql([<<~SQL, ids]))
      WITH RECURSIVE ancestors(id, parent_id) AS (
        SELECT id, parent_id FROM categories WHERE id IN (?)
        UNION
        SELECT categories.id, categories.parent_id FROM categories JOIN ancestors ON categories.id = ancestors.parent_id
      )
      SELECT id FROM ancestors
    SQL
  end

  private

  def slug_source = name

  # A product's document holds the names of its category's ancestors too, so the whole subtree changes.
  def refresh_product_search
    ids = Product.where(category_id: subtree_ids).ids
    ProductSearchRefreshJob.perform_later(ids) if ids.any?
  end

  # Read before the uuid cast, which turns a malformed id into nil.
  def parent_in_tenant
    errors.add(:parent_id, :invalid) if parent_id_before_type_cast.present? && parent.nil?
  end

  def linked_specifications_exist
    ids = @linked_specification_ids
    valid = ids.uniq.size == ids.size && Specification.where(id: ids).count == ids.size
    errors.add(:specification_links, :invalid) unless valid
  end

  def parent_outside_subtree
    errors.add(:parent_id, :invalid_parent) if parent_id && subtree_ids.include?(parent_id)
  end
end
