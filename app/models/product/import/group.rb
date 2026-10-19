# One handle's rows, parsed into product and variant attributes.
class Product::Import::Group
  VARIANT_ATTRIBUTES = {
    "price" => :price_cents, "pre_discount_price" => :pre_discount_price_cents, "vat_class" => :vat_class,
    "sku" => :sku, "barcode" => :barcode, "mpn" => :mpn, "stock" => :stock_quantity,
    "track_stock" => :track_stock, "allow_oversell" => :allow_oversell
  }.freeze
  PRICE = /\A(\d+)(?:[.,](\d{1,2}))?\z/
  STOCK = /\A-?\d+\z/
  BOOLEANS = { "true" => true, "1" => true, "false" => false, "0" => false }.freeze
  LIST = "|".freeze
  LEVEL = ">".freeze

  Variant = Data.define(:row, :option_values, :filled, :specifications) do
    # A blank VAT class means standard and a blank stock means zero. Other blank cells keep the model's defaults.
    #
    # @return [Hash] model attributes
    def attributes
      { option_values:, vat_class: "standard", stock_quantity: 0 }
        .merge(filled.transform_keys(Product::Import::Group::VARIANT_ATTRIBUTES))
    end
  end

  attr_reader :handle, :errors, :variants, :option_names, :category_path, :image_urls, :specifications

  # @param handle [String]
  # @param rows [Array<Array(CSV::Row, Integer)>] each row with its number in the file
  # @param option_count [Integer]
  # @param spec_keys [Hash{String => String}] each spec column's definition key
  def initialize(handle, rows, option_count, spec_keys)
    @handle = handle
    @rows = rows
    @errors = []
    @first, @first_number = rows.first
    @option_slots = (1..option_count).select { |n| cell(@first, "option#{n}_name").present? }
    @option_names = @option_slots.map { |n| cell(@first, "option#{n}_name") }
    @spec_columns = spec_keys.keys
    @spec_keys = spec_keys.transform_keys { |column| spec_name(column) }

    check_handle
    check_conflicts(option_count)
    @status = parse_status
    @category_path = parse_category
    @image_urls = parse_image_urls
    @specifications = parse_specifications(@first, @first_number)
    @variants = rows.map { |row, number| variant(row, number, option_count) }
  end

  def first_row = @first_number

  def row_numbers = @rows.map(&:last)

  def brand_name = cell(@first, "brand").presence

  def product_attributes
    {
      slug: handle, title: cell(@first, "title"), description: cell(@first, "description").presence,
      status: @status, option_names:, specifications:
    }
  end

  # @param variant [Variant]
  # @param inherited [Hash{String => Array<String>}] the product's spec values by definition key
  # @return [Hash] model attributes, with the spec cells that differ from the product's as overrides
  def variant_attributes(variant, inherited)
    overrides = variant.specifications.reject { |name, values| inherited[key(name)] == values }
    variant.attributes.merge(specifications: overrides)
  end

  # @param specifications [Hash{String => Array<String>}] keyed by the file's spec names
  # @return [Hash{String => Array<String>}] keyed by definition key
  def keyed(specifications) = specifications.transform_keys { |name| key(name) }

  # @param name [String] a spec name as the file spells it
  # @return [String]
  def key(name) = @spec_keys.fetch(name)

  # @return [Hash{String => String}] the product cells the file fills, keyed by column
  def filled_product_cells
    Product::Import::Sheet::PRODUCT_COLUMNS.excluding("handle")
                                           .to_h { |column| [column, cell(@first, column)] }.compact_blank
  end

  private

  def cell(row, column) = row[column].to_s.strip

  def add_error(code, field, row = @first_number)
    message = "#{Product::Import::Sheet.label(field)} #{I18n.t("errors.messages.#{code}")}"
    @errors << { code:, field:, row:, message: }
  end

  def check_handle
    return add_error("blank", "handle") if handle.empty?

    add_error("invalid", "handle") unless Sluggable::FORMAT.match?(handle)
  end

  def check_conflicts(option_count)
    columns = Product::Import::Sheet::PRODUCT_COLUMNS + (1..option_count).map { |n| "option#{n}_name" }
    @rows.drop(1).each do |row, number|
      columns.each do |column|
        value = cell(row, column)
        add_error("product_cell_conflict", column, number) unless value.empty? || value == cell(@first, column)
      end
    end
  end

  def parse_status
    value = cell(@first, "status")
    return "draft" if value.empty?

    add_error("invalid", "status") unless Product.statuses.key?(value)
    value
  end

  # @return [Array<String>, nil] nil when blank, which the product's validation reports
  def parse_category
    value = cell(@first, "category")
    return if value.empty?

    path = value.split(LEVEL).map(&:strip)
    # A list means the file still gives several categories, and a product has one.
    add_error("invalid", "category") if value.include?(LIST) || path.empty? || path.any?(&:empty?)
    path
  end

  def parse_image_urls
    urls = cell(@first, "image_urls").split(LIST).map { |url| Product::Image.encode_url(url.strip) }
                                     .compact_blank.uniq
    valid = urls.size <= Product::Image::MAX_PER_PRODUCT && urls.all? { |url| http_url?(url) }
    add_error("invalid", "image_urls") unless valid
    urls
  end

  # @return [Hash{String => Array<String>}] the row's filled spec cells, keyed by spec name
  def parse_specifications(row, number)
    @spec_columns.filter_map do |column|
      next if cell(row, column).empty?

      values = cell(row, column).split(LIST).map(&:strip).compact_blank.uniq
      add_error("invalid", column, number) if values.empty?
      [spec_name(column), values]
    end.to_h
  end

  def spec_name(column) = column[Product::Import::Sheet::SPEC_COLUMN, 1].strip

  def http_url?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) && uri.hostname.present?
  rescue URI::InvalidURIError
    false
  end

  def variant(row, number, option_count)
    (1..option_count).each do |n|
      next if @option_slots.include?(n) || cell(row, "option#{n}_value").empty?

      add_error("invalid", "option#{n}_value", number)
    end
    add_error("blank", "price", number) if cell(row, "price").empty?

    option_values = @option_slots.to_h { |n| [cell(@first, "option#{n}_name"), cell(row, "option#{n}_value")] }
    filled = VARIANT_ATTRIBUTES.keys.to_h { |column| [column, cell(row, column)] }.compact_blank
    parsed = filled.to_h { |column, value| [column, parse(column, value, number)] }
    specifications = number == @first_number ? @specifications : parse_specifications(row, number)
    Variant.new(row: number, option_values:, filled: parsed, specifications:)
  end

  def parse(column, value, number)
    parsed = case column
    when "price", "pre_discount_price" then cents(value)
    when "stock" then Integer(value, 10) if STOCK.match?(value)
    when "track_stock", "allow_oversell" then BOOLEANS[value.downcase]
    when "vat_class" then value if Product::Variant.vat_classes.key?(value)
    else value
    end
    parsed = nil if parsed.is_a?(Integer) && parsed.abs > Product::Variant::MAX_INTEGER
    add_error("invalid", column, number) if parsed.nil?
    parsed
  end

  def cents(value)
    whole, fraction = PRICE.match(value)&.captures
    whole && ((whole.to_i * 100) + fraction.to_s.ljust(2, "0").to_i)
  end
end
