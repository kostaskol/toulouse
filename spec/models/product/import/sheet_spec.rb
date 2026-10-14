require "rails_helper"

RSpec.describe Product::Import::Sheet, :as_tenant do
  let(:row) { { "handle" => "first", "title" => "First", "price" => "1" } }

  def error_code(text)
    described_class.new(text)
  rescue described_class::Error => error
    error.code
  end

  def error_message(text)
    described_class.new(text)
  rescue described_class::Error => error
    error.message if error.code == "unknown_columns"
  end

  it "groups rows by handle in order of first appearance" do
    text = import_csv([row, row.merge("handle" => "second"), row])

    expect(described_class.new(text).groups.map(&:handle)).to eq(["first", "second"])
  end

  it "reads a semicolon file" do
    expect(described_class.new(import_csv([row], col_sep: ";")).groups.map(&:handle)).to eq(["first"])
  end

  it "strips a byte-order mark" do
    expect(described_class.new("\uFEFF#{import_csv([row])}").text).to start_with("handle")
  end

  it "reads Windows line endings" do
    expect(described_class.new(import_csv([row]).gsub("\n", "\r\n")).groups.size).to eq(1)
  end

  it "skips rows of bare delimiters" do
    text = import_csv([row], col_sep: ";") + ";;\n;;\n"

    expect(described_class.new(text).groups.map(&:handle)).to eq(["first"])
  end

  it "counts a blank line in row numbers" do
    text = import_csv([row, row.merge("handle" => "second")]).sub("\nsecond", "\n\nsecond")

    expect(described_class.new(text).groups.last.first_row).to eq(4)
  end

  it "accepts header cells with stray spaces" do
    text = import_csv([row]).sub("price", " price ")

    expect(described_class.new(text).groups.size).to eq(1)
  end

  it "refuses a file over the cap" do
    stub_const("#{described_class}::MAX_BYTES", import_csv([row]).bytesize - 1)

    expect(error_code(import_csv([row]))).to eq("file_too_large")
  end

  it "refuses more rows than the cap" do
    stub_const("#{described_class}::MAX_ROWS", 1)

    expect(error_code(import_csv([row, row]))).to eq("file_too_large")
  end

  it "stops reading at the row cap" do
    stub_const("#{described_class}::MAX_ROWS", 1)

    expect(error_code("#{import_csv([row, row])}\"unclosed,x,1\n")).to eq("file_too_large")
  end

  it "refuses a header that starts with a blank line" do
    expect(error_message("\n#{import_csv([row])}")).to eq("The header row has a column with no name.")
  end

  it "refuses a header with a trailing delimiter" do
    expect(error_message(import_csv([row]).sub("price", "price,"))).to eq("The header row has a column with no name.")
  end

  it "refuses a NUL byte" do
    expect(error_code(import_csv([row.merge("title" => "Fi\0rst")]))).to eq("file_malformed")
  end

  it "refuses a file that is not UTF-8" do
    text = import_csv([row.merge("title" => "Μέλι")]).encode(Encoding::Windows_1253).b

    expect(error_code(text)).to eq("file_not_utf8")
  end

  it "refuses a file with no product rows" do
    expect(error_code(import_csv([row]).lines.first)).to eq("file_empty")
  end

  it "refuses an unknown column" do
    expect(error_code(import_csv([row.merge("prcie" => "1")]))).to eq("unknown_columns")
  end

  it "refuses a missing required column" do
    expect(error_code(import_csv([row.except("price")]))).to eq("missing_columns")
  end

  it "refuses a repeated column" do
    expect(error_code(import_csv([row]).sub("price", "price,price"))).to eq("duplicate_columns")
  end

  it "accepts spec columns" do
    expect { described_class.new(import_csv([row.merge("spec:Υλικό" => "Λινό")])) }.not_to raise_error
  end

  it "refuses a spec column with no name" do
    expect(error_code(import_csv([row.merge("spec: " => "Λινό")]))).to eq("unknown_columns")
  end

  it "refuses two spec columns that fold alike, as definitions fold" do
    expect(error_code(import_csv([row.merge("spec:Υλικό" => "Λινό", "spec:υλικο" => "Λινό")])))
      .to eq("duplicate_columns")
    expect(error_code(import_csv([row.merge("spec:Μέγεθος [EU]" => "42", "spec:Μέγεθος EU" => "42")])))
      .to eq("duplicate_columns")
  end

  it "refuses an option name with no value column" do
    expect(error_code(import_csv([row.merge("option1_name" => "Size")]))).to eq("option_columns_invalid")
  end

  it "refuses a gap in the option columns" do
    text = import_csv([row.merge("option2_name" => "Size", "option2_value" => "S")])

    expect(error_code(text)).to eq("option_columns_invalid")
  end

  it "refuses a file that does not parse" do
    expect(error_code(import_csv([row]) + "\"unclosed,x,1\n")).to eq("file_malformed")
  end
end
