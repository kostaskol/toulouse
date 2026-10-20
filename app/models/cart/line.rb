class Cart::Line < ApplicationRecord
  include Tenancy::Scoped

  MAX_QUANTITY = Product::Variant::MAX_INTEGER

  belongs_to :cart, inverse_of: :lines
  belongs_to :variant, class_name: "Product::Variant"

  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_QUANTITY }

  # @param quantity [Integer]
  def add(quantity)
    update!(quantity: [self.quantity.to_i + quantity, MAX_QUANTITY].min)
  end

  # @return [Integer] the most this line can hold
  def quantity_limit = variant.limits_stock? ? variant.stock_quantity : MAX_QUANTITY

  # @return [String] buyable, over_stock or unavailable
  def state
    return "unavailable" unless variant.sellable?

    quantity > quantity_limit ? "over_stock" : "buyable"
  end

  # @return [Integer] how many of this line an order could take now
  def buyable_quantity = variant.sellable? ? [quantity, quantity_limit].min : 0
end
