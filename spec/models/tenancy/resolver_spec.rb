require "rails_helper"

RSpec.describe Tenancy::Resolver do
  it "fails with missing_api_key when there is no token" do
    expect(described_class.call(nil).reason).to eq(:missing_api_key)
  end

  it "fails with missing_api_key for an empty token" do
    expect(described_class.call("").reason).to eq(:missing_api_key)
  end

  it "fails with missing_api_key for a whitespace token" do
    expect(described_class.call(" \t ").reason).to eq(:missing_api_key)
  end

  it "fails with invalid_api_key for an unknown token" do
    key = create(:tenant_api_key)

    expect(described_class.call(key.token_prefix).reason).to eq(:invalid_api_key)
  end

  it "fails with invalid_api_key for a revoked key" do
    key = create(:tenant_api_key, revoked_at: 1.minute.ago)

    expect(described_class.call(key.token).reason).to eq(:invalid_api_key)
  end

  it "fails with invalid_api_key for an expired key" do
    key = create(:tenant_api_key, expires_at: 1.minute.ago)

    expect(described_class.call(key.token).reason).to eq(:invalid_api_key)
  end

  it "fails with inactive for a pending tenant" do
    key = create(:tenant_api_key, tenant: create(:tenant, status: :pending))

    expect(described_class.call(key.token).reason).to eq(:inactive)
  end

  it "fails with inactive for a suspended tenant" do
    key = create(:tenant_api_key, tenant: create(:tenant, status: :suspended))

    expect(described_class.call(key.token).reason).to eq(:inactive)
  end

  it "resolves an active tenant" do
    key = create(:tenant_api_key)
    resolution = described_class.call(key.token)

    expect(resolution).to be_resolved
    expect(resolution.tenant).to eq(key.tenant)
  end

  it "resolves each token to its own tenant" do
    first = create(:tenant_api_key)
    second = create(:tenant_api_key)

    expect(described_class.call(first.token).tenant).to eq(first.tenant)
    expect(described_class.call(second.token).tenant).to eq(second.tenant)
  end

  it "issues no query on a cache hit" do
    key = create(:tenant_api_key, last_used_at: Time.current)
    described_class.call(key.token)

    expect(count_queries { described_class.call(key.token) }).to eq(0)
  end

  it "does not cache a failure" do
    key = create(:tenant_api_key, tenant: create(:tenant, status: :pending))
    described_class.call(key.token)

    Tenant.where(id: key.tenant_id).update_all(status: Tenant.statuses.fetch("active"))

    expect(described_class.call(key.token)).to be_resolved
  end

  it "stamps last_used_at on the first resolution" do
    key = create(:tenant_api_key)

    described_class.call(key.token)

    expect(key.reload.last_used_at).to be_within(5.seconds).of(Time.current)
  end

  it "re-reads the tenant once the cached entry expires" do
    key = create(:tenant_api_key)
    described_class.call(key.token)

    Tenant.where(id: key.tenant_id).update_all(status: Tenant.statuses.fetch("suspended"))

    travel(Tenancy::ResolutionCache::TTL + 1.second) do
      expect(described_class.call(key.token).reason).to eq(:inactive)
    end
  end
end
