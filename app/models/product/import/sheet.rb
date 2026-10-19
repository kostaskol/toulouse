require "csv"

# The canonical import CSV, checked as a whole and grouped by handle.
class Product::Import::Sheet
  MAX_BYTES = 10.megabytes
  MAX_ROWS = 50_000
  BOM = "\uFEFF".freeze
  PRODUCT_COLUMNS = ["handle", "title", "description", "status", "brand", "category", "image_urls"].freeze
  VARIANT_COLUMNS = [
    "price", "pre_discount_price", "vat_class", "sku", "barcode", "mpn", "stock", "track_stock", "allow_oversell"
  ].freeze
  REQUIRED_COLUMNS = ["handle", "title", "price"].freeze
  SPEC_COLUMN = /\Aspecification:(.*\S.*)\z/
  # Images for each value of one selectable spec, on the first row of that value.
  IMAGE_COLUMN = /\Aimage_urls:(.*\S.*)\z/

  class Error < StandardError
    attr_reader :code, :columns

    # @param code [String]
    # @param message [String]
    # @param columns [Array<String>, nil] the header columns at fault, so a client can name them in its own words
    def initialize(code, message, columns: nil)
      @code = code
      @columns = columns
      super(message)
    end
  end

  attr_reader :text

  # Columns that name a spec keep the merchant's spelling.
  #
  # @param column [String]
  # @return [String]
  def self.label(column) = column.match?(SPEC_COLUMN) || column.match?(IMAGE_COLUMN) ? column : column.humanize

  # @param text [String] the upload as received, in any encoding
  def initialize(text)
    if text.bytesize > MAX_BYTES
      raise Error.new("file_too_large", "The file must be at most #{MAX_BYTES / 1.megabyte} MB.")
    end

    @text = text.dup.force_encoding(Encoding::UTF_8).delete_prefix(BOM)
    unless @text.valid_encoding?
      raise Error.new("file_not_utf8", "The file is not UTF-8. Save it from your spreadsheet as \"CSV UTF-8\".")
    end

    # Postgres text cannot store a NUL byte.
    if @text.include?("\0")
      raise Error.new("file_malformed", "The file has a NUL character. Save it from your spreadsheet as CSV again.")
    end

    header = @text.each_line.first.to_s
    @col_sep = header.count(";") > header.count(",") ? ";" : ","
    headers, count = scan
    @spec_keys, @image_columns = check_header(headers)
    raise Error.new("file_empty", "The file has no product rows.") if count.zero?
  end

  # @return [Array<Product::Import::Group>] one per handle, in order of first appearance
  def groups
    @groups ||= numbered_rows.group_by { |row, _| row["handle"].to_s.strip }.map do |handle, group_rows|
      Product::Import::Group.new(handle, group_rows, @spec_keys, @image_columns)
    end
  end

  private

  def reader = CSV.new(@text, headers: true, col_sep: @col_sep, header_converters: ->(name) { name.to_s.strip })

  # Streams the rows and keeps none, so an oversize file stops at the cap without filling memory.
  #
  # @return [Array(Array<String, nil>, Integer)] the header and how many data rows follow it
  def scan
    csv = reader
    count = 0
    csv.each do |row|
      next if blank?(row)

      count += 1
      raise Error.new("file_too_large", "The file must have at most #{MAX_ROWS} product rows.") if count > MAX_ROWS
    end
    # An empty file never reaches a header row.
    raise Error.new("file_empty", "The file has no product rows.") unless csv.headers.is_a?(Array)

    [csv.headers, count]
  rescue CSV::MalformedCSVError => error
    raise Error.new("file_malformed", "The file is not valid CSV near line #{error.line_number}.")
  end

  # @return [Array(Hash{String => String}, Hash{String => String})] each spec column's definition key, and each
  #   image column's spec column
  def check_header(headers)
    if headers.empty? || headers.any?(&:blank?)
      raise Error.new("blank_column", "The header row has a column with no name.")
    end

    repeated = headers.tally.select { |_, count| count > 1 }.keys
    if repeated.any?
      raise Error.new("duplicate_columns", "Repeated columns: #{repeated.join(', ')}.", columns: repeated)
    end

    specs = headers.grep(SPEC_COLUMN)
    images = headers.grep(IMAGE_COLUMN)
    unknown = headers - PRODUCT_COLUMNS - VARIANT_COLUMNS - specs - images
    raise Error.new("unknown_columns", "Unknown columns: #{unknown.join(', ')}.", columns: unknown) if unknown.any?

    # Folded as spec definitions are, since two columns that fold alike would write one spec.
    spec_keys = specs.zip(Specification.fold(specs.map { |column| column[SPEC_COLUMN, 1] })).to_h
    image_keys = images.zip(Specification.fold(images.map { |column| column[IMAGE_COLUMN, 1] })).to_h
    alike = [spec_keys, image_keys].flat_map { |keys| keys.group_by(&:last).values.select(&:many?).flatten(1) }
                                   .map(&:first)
    raise Error.new("duplicate_columns", "Repeated columns: #{alike.join(', ')}.", columns: alike) if alike.any?

    image_columns = image_keys.to_h { |column, key| [column, spec_keys.key(key)] }
    unpaired = image_columns.select { |_, spec_column| spec_column.nil? }.keys
    if unpaired.any?
      raise Error.new("unknown_columns", "Image columns with no specification column: #{unpaired.join(', ')}.",
                      columns: unpaired)
    end

    missing = REQUIRED_COLUMNS - headers
    raise Error.new("missing_columns", "Missing columns: #{missing.join(', ')}.", columns: missing) if missing.any?

    [spec_keys, image_columns]
  end

  # Row numbers count the header as row 1, as a spreadsheet shows them.
  def numbered_rows = reader.each.with_index(2).reject { |row, _| blank?(row) }

  def blank?(row) = row.fields.all?(&:blank?)
end
