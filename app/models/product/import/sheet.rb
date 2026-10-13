require "csv"

# The canonical import CSV, checked as a whole and grouped by handle.
class Product::Import::Sheet
  MAX_BYTES = 10.megabytes
  MAX_ROWS = 50_000
  BOM = "\uFEFF".freeze
  PRODUCT_COLUMNS = ["handle", "title", "description", "status", "brand", "categories", "image_urls"].freeze
  VARIANT_COLUMNS = [
    "price", "pre_discount_price", "vat_class", "sku", "barcode", "mpn", "stock", "track_stock", "allow_oversell"
  ].freeze
  REQUIRED_COLUMNS = ["handle", "title", "price"].freeze
  OPTION_COLUMN = /\Aoption([1-9]\d*)_(?:name|value)\z/

  class Error < StandardError
    attr_reader :code

    # @param code [String]
    # @param message [String]
    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  attr_reader :text

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
    @option_count = check_header(headers)
    raise Error.new("file_empty", "The file has no product rows.") if count.zero?
  end

  # @return [Array<Product::Import::Group>] one per handle, in order of first appearance
  def groups
    @groups ||= numbered_rows.group_by { |row, _| row["handle"].to_s.strip }
                             .map { |handle, group_rows| Product::Import::Group.new(handle, group_rows, @option_count) }
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

  # @return [Integer] how many option column pairs the header has
  def check_header(headers)
    if headers.empty? || headers.any?(&:blank?)
      raise Error.new("unknown_columns", "The header row has a column with no name.")
    end

    repeated = headers.tally.select { |_, count| count > 1 }.keys
    raise Error.new("duplicate_columns", "Repeated columns: #{repeated.join(', ')}.") if repeated.any?

    options = headers.grep(OPTION_COLUMN)
    unknown = headers - PRODUCT_COLUMNS - VARIANT_COLUMNS - options
    raise Error.new("unknown_columns", "Unknown columns: #{unknown.join(', ')}.") if unknown.any?

    missing = REQUIRED_COLUMNS - headers
    raise Error.new("missing_columns", "Missing columns: #{missing.join(', ')}.") if missing.any?

    count = options.map { |name| name[OPTION_COLUMN, 1].to_i }.max || 0
    paired = (1..count).all? { |n| headers.include?("option#{n}_name") && headers.include?("option#{n}_value") }
    unless paired
      raise Error.new("option_columns_invalid", "Option columns must come in name and value pairs from 1 up.")
    end

    count
  end

  # Row numbers count the header as row 1, as a spreadsheet shows them.
  def numbered_rows = reader.each.with_index(2).reject { |row, _| blank?(row) }

  def blank?(row) = row.fields.all?(&:blank?)
end
