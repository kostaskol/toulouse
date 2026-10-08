require "rails_helper"

RSpec.describe PurgeExpiredLoginsJob do
  let(:tenants) { create_list(:tenant, 2) }

  def count_in(tenant, model)
    as_tenant(tenant) { model.count }
  end

  it "removes expired login attempts in every tenant" do
    tenants.each { |tenant| create(:login_attempt, tenant:, failed_count: 1, last_failed_at: Time.current) }
    travel LoginAttempt::WINDOW + 1.second

    described_class.perform_now

    expect(tenants.map { |tenant| count_in(tenant, LoginAttempt) }).to all(eq(0))
  end

  it "keeps login attempts inside their window" do
    tenant = tenants.first
    create(:login_attempt, tenant:, failed_count: 1, last_failed_at: Time.current)

    described_class.perform_now

    expect(count_in(tenant, LoginAttempt)).to eq(1)
  end

  it "removes expired staff sessions in every tenant" do
    tenants.each { |tenant| create(:staff_session, tenant:) }
    travel Staff::Session::IDLE_TIMEOUT + 1.second

    described_class.perform_now

    expect(tenants.map { |tenant| count_in(tenant, Staff::Session) }).to all(eq(0))
  end

  it "keeps live staff sessions" do
    tenant = tenants.first
    create(:staff_session, tenant:)

    described_class.perform_now

    expect(count_in(tenant, Staff::Session)).to eq(1)
  end

  it "removes expired shopper sessions in every tenant" do
    tenants.each { |tenant| create(:shopper_session, tenant:) }
    travel Shopper::Session::IDLE_TIMEOUT + 1.second

    described_class.perform_now

    expect(tenants.map { |tenant| count_in(tenant, Shopper::Session) }).to all(eq(0))
  end

  it "keeps live shopper sessions" do
    tenant = tenants.first
    create(:shopper_session, tenant:)

    described_class.perform_now

    expect(count_in(tenant, Shopper::Session)).to eq(1)
  end

  it "removes expired signup codes in every tenant" do
    tenants.each { |tenant| as_tenant(tenant) { Shopper::SignupCode.issue(build(:shopper).email) } }
    travel Shopper::SignupCode::EXPIRY + 1.second

    described_class.perform_now

    expect(tenants.map { |tenant| count_in(tenant, Shopper::SignupCode) }).to all(eq(0))
  end

  it "keeps live signup codes" do
    tenant = tenants.first
    as_tenant(tenant) { Shopper::SignupCode.issue(build(:shopper).email) }

    described_class.perform_now

    expect(count_in(tenant, Shopper::SignupCode)).to eq(1)
  end
end
