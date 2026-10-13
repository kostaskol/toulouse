class Product::Import::Group
  attr_reader :handle

  def initialize(handle, _rows, _option_count)
    @handle = handle
  end
end
