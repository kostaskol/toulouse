# Specs written as names and their values. Each write replaces every spec the record states.
module HasSpecifications
  extend ActiveSupport::Concern

  included do
    validate :specifications_valid, if: -> { @specifications }
    before_save { @saved_specifications = false }
    before_save :write_specifications, if: -> { @specifications }
  end

  # @param specifications [Hash{String => Array<String>}] values in display order
  def specifications=(specifications)
    @specifications = specifications.respond_to?(:permitted?) ? specifications.to_h : specifications
  end

  # @return [Hash{String => Array<String>}]
  def specifications
    @specifications || specification_entries.to_h { |specification, values| [specification.name, values] }
  end

  # @return [Array(Specification, Array<String>)] each spec with its values, in definition order
  def specification_entries
    specification_values.group_by(&:specification)
                        .sort_by { |specification, _| [specification.position, specification.id] }
                        .map { |specification, values| [specification, values.sort_by(&:position).map(&:value)] }
  end

  # True after a save that wrote specs, until the next save.
  def saved_change_to_specifications? = @saved_specifications

  private

  def specifications_valid
    valid = @specifications.is_a?(Hash) && @specifications.all? do |name, values|
      name.is_a?(String) && name.strip.present? && values.is_a?(Array) && values.any? &&
        values.all? { |value| value.is_a?(String) && value.strip.present? }
    end
    # Two names that fold alike would land on one definition.
    valid &&= Specification.fold(@specifications.keys).uniq.size == @specifications.size
    errors.add(:specifications, :invalid) unless valid
  end

  # Keeps rows whose value stays, so the audit log shows only real changes.
  def write_specifications
    definitions = Specification.resolve(@specifications.keys)
    wanted = @specifications.flat_map do |name, values|
      values.map(&:strip).uniq.each_with_index.map { |value, position| [definitions.fetch(name), value, position] }
    end
    stored = specification_values.to_a
    stored.each do |row|
      match = wanted.find { |definition, value, _| definition.id == row.specification_id && value == row.value }
      match ? row.position = match.last : row.mark_for_destruction
    end
    wanted.each do |definition, value, position|
      next if stored.any? { |row| row.specification_id == definition.id && row.value == value }

      specification_values.build(specification: definition, value:, position:)
    end
    @specifications = nil
    @saved_specifications = true
  end
end
