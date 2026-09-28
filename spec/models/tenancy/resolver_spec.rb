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
    key = Tenancy.across_tenants { create(:tenant_api_key) }

    expect(described_class.call(key.token_prefix).reason).to eq(:invalid_api_key)
  end

  # Puma tags header values ASCII-8BIT, but another rack server may hand back
  # UTF-8, where invalid bytes raise from String#blank?.
  it "fails with invalid_api_key for a token tagged UTF-8 with invalid bytes" do
    token = "#{Tenant::ApiKey::TOKEN_PREFIX}\xC3".dup.force_encoding(Encoding::UTF_8)

    expect(described_class.call(token).reason).to eq(:invalid_api_key)
  end

  it "fails with invalid_api_key for a revoked key" do
    key = Tenancy.across_tenants { create(:tenant_api_key, revoked_at: 1.minute.ago) }

    expect(described_class.call(key.token).reason).to eq(:invalid_api_key)
  end

  it "fails with invalid_api_key for an expired key" do
    key = Tenancy.across_tenants { create(:tenant_api_key, expires_at: 1.minute.ago) }

    expect(described_class.call(key.token).reason).to eq(:invalid_api_key)
  end

  it "fails with inactive for a pending tenant" do
    key = Tenancy.across_tenants { create(:tenant_api_key, tenant: create(:tenant, status: :pending)) }

    expect(described_class.call(key.token).reason).to eq(:inactive)
  end

  it "fails with inactive for a suspended tenant" do
    key = Tenancy.across_tenants { create(:tenant_api_key, tenant: create(:tenant, status: :suspended)) }

    expect(described_class.call(key.token).reason).to eq(:inactive)
  end

  it "resolves an active tenant" do
    key = Tenancy.across_tenants { create(:tenant_api_key) }
    resolution = described_class.call(key.token)

    expect(resolution).to be_resolved
    expect(resolution.tenant).to eq(key.tenant)
  end

  it "resolves each token to its own tenant" do
    first = Tenancy.across_tenants { create(:tenant_api_key) }
    second = Tenancy.across_tenants { create(:tenant_api_key) }

    expect(described_class.call(first.token).tenant).to eq(first.tenant)
    expect(described_class.call(second.token).tenant).to eq(second.tenant)
  end

  it "stamps last_used_at on the first resolution" do
    key = Tenancy.across_tenants { create(:tenant_api_key) }

    described_class.call(key.token)

    expect(key.reload.last_used_at).to be_within(5.seconds).of(Time.current)
  end

  it "rejects a key revoked since the last resolution" do
    key = Tenancy.across_tenants { create(:tenant_api_key) }
    described_class.call(key.token)

    Tenancy.across_tenants { key.update!(revoked_at: Time.current) }

    expect(described_class.call(key.token).reason).to eq(:invalid_api_key)
  end

  it "rejects a tenant suspended since the last resolution" do
    key = Tenancy.across_tenants { create(:tenant_api_key) }
    described_class.call(key.token)

    key.tenant.update!(status: :suspended)

    expect(described_class.call(key.token).reason).to eq(:inactive)
  end
end
