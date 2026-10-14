# Writes one handle's rows: creates a new product or adds new variants to an existing one.
class Product::Import::Writer
  WARNINGS = {
    "product_cell_ignored" => "is ignored because the product already exists",
    "variant_cell_ignored" => "is ignored because the variant already exists",
    "image_urls_ignored" => "are ignored because the product already exists"
  }.freeze
  # Model attributes reported under the file's column names.
  COLUMNS = Product::Import::Group::VARIANT_ATTRIBUTES.invert
    .merge(slug: "handle", brand_id: "brand", category_ids: "categories").transform_keys(&:to_s).freeze

  # Carries the file row of a variant that failed validation.
  class RowInvalid < ActiveRecord::RecordInvalid
    attr_reader :row

    # @param record [ActiveRecord::Base]
    # @param row [Integer]
    def initialize(record, row)
      @row = row
      super(record)
    end
  end

  # @param group [Product::Import::Group]
  def initialize(group)
    @group = group
    @warnings = []
    @created_brands = []
    @created_categories = []
  end

  # Writes the group in its own savepoint, so a failed product leaves nothing behind.
  #
  # @return [Hash] entry attributes
  def call
    return failure(@group.errors) if @group.errors.any?

    Product.transaction(requires_new: true) do
      product = Product.find_by(slug: @group.handle)
      product ? add_variants(product) : create_product
    end
  rescue ActiveRecord::RecordInvalid => error
    failure(model_errors(error.record, error.try(:row) || @group.first_row))
  end

  private

  def failure(error_details)
    entry("failed", nil, error_details:, warnings: [], created_brands: [], created_categories: [])
  end

  def entry(result, product, error_details: [], warnings: @warnings, created_brands: @created_brands,
            created_categories: @created_categories)
    {
      handle: @group.handle, rows: @group.row_numbers, result:, product_id: product&.id, error_details:, warnings:,
      created_brands:, created_categories:
    }
  end

  def create_product
    product = Product.create!(
      **@group.product_attributes, brand:, category_ids: @group.category_paths.map { |path| category(path).id }.uniq,
      variants_attributes: @group.variants.map do |variant|
        @group.variant_attributes(variant, @group.keyed(@group.specifications))
      end
    )
    entry("created", product)
  end

  def add_variants(product)
    unless @group.option_names == product.option_names
      product.errors.add(:option_names, :option_names_mismatch)
      raise ActiveRecord::RecordInvalid, product
    end

    warn_product_cells(product)
    inherited = stored_by_key(product)
    stored = product.variants.index_by(&:option_values)
    added = 0
    @group.variants.each do |variant|
      if stored.key?(variant.option_values)
        warn_variant_cells(variant, stored[variant.option_values], inherited)
      else
        create_variant(product, variant, inherited)
        added += 1
      end
    end
    entry(added.zero? ? "skipped" : "updated", product)
  end

  def create_variant(product, variant, inherited)
    product.variants.create!(@group.variant_attributes(variant, inherited))
  rescue ActiveRecord::RecordInvalid => error
    raise RowInvalid.new(error.record, variant.row)
  end

  def brand
    name = @group.brand_name
    return unless name

    Brand.find_by(name:) || Brand.create!(name:).tap { @created_brands << name }
  end

  # @return [Category, nil] nil only when not creating and a level is missing
  def category(path, create: true)
    path.each_with_index.reduce(nil) do |parent, (name, depth)|
      found = Category.where(parent:, name:).order(:position, :id).first
      next found if found
      return unless create

      Category.create!(parent:, name:).tap { @created_categories << path.first(depth + 1).join(" > ") }
    end
  end

  def warn_product_cells(product)
    stored = {
      "title" => product.title, "description" => product.description.to_s, "status" => product.status,
      "brand" => product.brand&.name.to_s, "categories" => product.categories.map(&:name).join(" | ")
    }
    @group.filled_product_cells.each do |column, value|
      next add_warning("image_urls_ignored", column, nil) if column == "image_urls"
      next if column == "categories" ? same_categories?(product) : value == stored[column]

      add_warning("product_cell_ignored", column, stored[column])
    end
  end

  # @return [Hash{String => Array<String>}] the record's own spec values by definition key
  def stored_by_key(record) = record.specification_entries.to_h { |specification, values| [specification.key, values] }

  def same_categories?(product)
    ids = @group.category_paths.map { |path| category(path, create: false)&.id }
    ids.all? && ids.uniq.sort == product.category_ids.sort
  end

  # On an existing product every spec cell is a variant cell, as a new variant's cell becomes its override.
  def warn_variant_cells(variant, existing, inherited)
    variant.filled.each do |column, value|
      stored = existing.public_send(Product::Import::Group::VARIANT_ATTRIBUTES.fetch(column))
      add_warning("variant_cell_ignored", column, display(column, stored), row: variant.row) unless value == stored
    end
    effective = inherited.merge(stored_by_key(existing))
    variant.specifications.each do |name, values|
      kept = effective[@group.key(name)]
      add_warning("variant_cell_ignored", "spec:#{name}", kept.to_a.join(" | "), row: variant.row) unless values == kept
    end
  end

  def add_warning(code, field, stored, row: @group.first_row)
    message = "#{Product::Import::Sheet.label(field)} #{WARNINGS.fetch(code)}"
    @warnings << { code:, field:, row:, stored:, message: }.compact
  end

  def display(column, value)
    return value.to_s unless column.end_with?("price") && value

    format("%d.%02d", value / 100, value % 100)
  end

  def model_errors(record, row)
    record.errors.map do |error|
      index, attribute = error.attribute.to_s.match(/\Avariants\[(\d+)\]\.(.+)\z/)&.captures
      attribute ||= error.attribute.to_s
      {
        code: error.type.to_s, field: field(record, attribute), row: index ? @group.variants[index.to_i].row : row,
        message: error.full_message
      }.compact
    end
  end

  def field(record, attribute)
    return if attribute == "base"
    return "brand" if record.is_a?(Brand)
    return "categories" if record.is_a?(Category)
    return "option1_value" if attribute == "option_values" && @group.option_names.any?

    COLUMNS.fetch(attribute, attribute)
  end
end
