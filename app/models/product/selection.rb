# Judges the rules by which a product's variants differ: one spec per kind, a value for every selectable spec
# in use, and no two variants alike. Unsaved spec writes count.
class Product::Selection
  # @param product [Product]
  # @param variant [Product::Variant, nil] a variant saving on its own, judged with its siblings
  # @param definitions [Hash{String => Specification}, nil] by key, to judge a definition before it saves
  def initialize(product, variant: nil, definitions: nil)
    # No database constraint can state these rules, so saves of one product queue before its variants load.
    Product.where(id: product.id).lock.pick(:id) if product.persisted?
    variants = variant ? [*variant.siblings, variant] : product.variants.to_a
    ActiveRecord::Associations::Preloader.new(records: variants.select(&:persisted?),
                                              associations: { specification_values: :specification }).call
    own = product.keyed_specifications
    effective = variants.to_h { |each_variant| [each_variant, own.merge(each_variant.keyed_specifications)] }
    keys = [own, *effective.values].flat_map(&:keys).uniq
    used = definitions ? definitions.values_at(*keys).compact : Specification.where(key: keys).to_a

    @faults = {}
    @faults[product] = :kind_taken if used.reject(&:kind_none?).group_by(&:kind).values.any?(&:many?)
    judge(effective, used.select(&:selectable).map(&:key))
  end

  # @param record [Product, Product::Variant]
  # @return [Symbol, nil] kind_taken for the product, selection_incomplete or duplicate_combination for a variant
  def fault(record) = @faults[record]

  # @return [Array<Symbol>] every fault found, once each
  def faults = @faults.values.uniq

  private

  def judge(effective, selectable)
    effective.each do |variant, values|
      @faults[variant] = :selection_incomplete if variant.active? && !(selectable - values.keys).empty?
    end
    effective.group_by { |_, values| values.slice(*selectable) }.each_value do |same|
      same.each { |variant, _| @faults[variant] ||= :duplicate_combination } if same.many?
    end
  end
end
