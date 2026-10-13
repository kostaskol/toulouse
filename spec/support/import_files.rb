module ImportFiles
  # @param rows [Array<Hash{String => String}>]
  # @param col_sep [String]
  # @return [String] a CSV with a header of every column the rows use
  def import_csv(rows, col_sep: ",")
    columns = rows.flat_map(&:keys).uniq
    CSV.generate(col_sep:) do |csv|
      csv << columns
      rows.each { |row| csv << row.values_at(*columns) }
    end
  end
end

RSpec.configure { |config| config.include ImportFiles }
