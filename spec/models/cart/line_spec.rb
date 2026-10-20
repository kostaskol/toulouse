require "rails_helper"

RSpec.describe Cart::Line do
  let(:tenant) { as_tenant }
  let(:line) { create(:cart_line, quantity: 2).tap { |line| line.variant.update!(stock_quantity: 2) } }

  before { tenant }

  it "is buyable while the stock covers it" do
    expect([line.state, line.buyable_quantity]).to eq(["buyable", 2])
  end

  it "is over stock when the stock drops below it" do
    line.variant.update!(stock_quantity: 1)

    expect([line.state, line.buyable_quantity]).to eq(["over_stock", 1])
  end

  it "is unavailable when the variant sells out" do
    line.variant.update!(stock_quantity: 0)

    expect([line.state, line.buyable_quantity]).to eq(["unavailable", 0])
  end

  it "is unavailable when the product leaves the store" do
    line.variant.product.update!(status: "draft")

    expect(line.state).to eq("unavailable")
  end

  it "is unavailable when the variant is archived" do
    create(:product_variant, product: line.variant.product)
    line.variant.update!(status: "archived")

    expect(line.state).to eq("unavailable")
  end

  it "ignores stock for a variant that does not track it" do
    line.variant.update!(track_stock: false, stock_quantity: 0)

    expect(line.state).to eq("buyable")
  end
end
