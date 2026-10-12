require "rails_helper"

RSpec.describe "Tenant admin stock", type: :request do
  let(:tenant) { create(:tenant) }
  let(:staff) { create(:staff, tenant:) }
  let(:headers) { staff_cookie(create(:staff_session, tenant:, staff:)) }
  let(:product) { as_tenant(tenant) { create(:product) } }
  let(:variant) { product.variants.first }

  def change_stock(**body)
    patch "/admin/products/#{product.id}/variants/#{variant.id}/stock", params: body, headers: headers, as: :json
  end

  def stock = as_tenant(tenant) { variant.reload.stock_quantity }

  it "starts a new variant tracked, at zero, without oversell" do
    expect(variant).to have_attributes(track_stock: true, stock_quantity: 0, allow_oversell: false)
  end

  it "sets the counted stock" do
    change_stock(quantity: 7)

    expect(response.parsed_body.dig("variant", "stock_quantity")).to eq(7)
  end

  it "adds a delta to the current stock" do
    change_stock(quantity: 7)
    change_stock(delta: -2)

    expect(stock).to eq(5)
  end

  it "reads a delta with a leading zero as decimal" do
    change_stock(delta: "010")

    expect(stock).to eq(10)
  end

  it "refuses to go below zero without oversell" do
    change_stock(delta: -1)

    expect(response.parsed_body["errors"])
      .to contain_exactly(include("code" => "insufficient_stock", "field" => "stock_quantity"))
    expect(stock).to eq(0)
  end

  it "goes below zero with oversell" do
    as_tenant(tenant) { variant.update!(allow_oversell: true) }
    change_stock(delta: -1)

    expect(stock).to eq(-1)
  end

  [{}, { quantity: 1, delta: 1 }, { delta: 1.5 }, { delta: "many" }, { quantity: nil }].each do |body|
    it "refuses #{body.inspect}" do
      change_stock(**body)

      expect_failure(Admin::StocksController::FAILURES.fetch(:invalid_stock_change))
    end
  end

  it "records the reason and who changed it" do
    reason = SecureRandom.alphanumeric(8)
    change_stock(delta: 1, reason:)

    version = as_tenant(tenant) { Version.where(item_id: variant.id).last }
    expect(version).to have_attributes(reason:, whodunnit: staff.to_global_id.to_s)
  end
end
