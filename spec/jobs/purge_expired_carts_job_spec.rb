require "rails_helper"

RSpec.describe PurgeExpiredCartsJob do
  let(:tenants) { create_list(:tenant, 2) }

  def count_in(tenant) = as_tenant(tenant) { Cart.count }

  it "removes expired guest carts in every tenant" do
    tenants.each { |tenant| as_tenant(tenant) { Cart.create! } }
    travel Cart::GUEST_IDLE_TIMEOUT + 1.second

    described_class.perform_now

    expect(tenants.map { |tenant| count_in(tenant) }).to all(eq(0))
  end

  it "keeps live guest carts and every shopper's cart" do
    tenant = tenants.first
    as_tenant(tenant) { Cart.create! }
    create(:cart, tenant:)
    travel Cart::GUEST_IDLE_TIMEOUT - 1.second

    described_class.perform_now

    expect(count_in(tenant)).to eq(2)
  end
end
