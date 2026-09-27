require "rails_helper"

RSpec.describe Tenancy::ResolutionCache do
  let(:api_key) { create(:tenant_api_key) }
  let(:digest) { api_key.token_digest }

  it "returns nil for a digest it has never seen" do
    expect(described_class.read(Tenant::ApiKey.digest(api_key.token_prefix))).to be_nil
  end

  it "reads back an entry it wrote" do
    described_class.write(digest, api_key)
    entry = described_class.read(digest)

    expect(entry.api_key_id).to eq(api_key.id)
    expect(entry.last_used_at).to eq(api_key.last_used_at)
    expect(entry.tenant).to eq(api_key.tenant)
  end

  it "builds the tenant without a query" do
    described_class.write(digest, api_key)
    entry = described_class.read(digest)

    expect(count_queries { entry.tenant }).to eq(0)
  end

  it "builds a tenant that is persisted and fully attributed" do
    described_class.write(digest, api_key)
    tenant = described_class.read(digest).tenant

    expect(tenant).to be_persisted
    expect(tenant.status).to eq(api_key.tenant.status)
    expect(tenant.slug).to eq(api_key.tenant.slug)
  end

  it "hands out a separate tenant object per read" do
    described_class.write(digest, api_key)

    first = described_class.read(digest).tenant
    second = described_class.read(digest).tenant
    first.name = first.name.reverse

    expect(first).not_to equal(second)
    expect(second.name).to eq(api_key.tenant.name)
  end

  it "keeps an entry until the TTL elapses" do
    described_class.write(digest, api_key)

    travel(described_class::TTL - 1.second) do
      expect(described_class.read(digest)).not_to be_nil
    end
  end

  it "drops an entry once the TTL has elapsed" do
    described_class.write(digest, api_key)

    travel(described_class::TTL + 1.second) do
      expect(described_class.read(digest)).to be_nil
    end
  end

  it "keeps entries for different digests apart" do
    other = create(:tenant_api_key)
    described_class.write(digest, api_key)
    described_class.write(other.token_digest, other)

    expect(described_class.read(digest).tenant).to eq(api_key.tenant)
    expect(described_class.read(other.token_digest).tenant).to eq(other.tenant)
  end

  it "drops everything on clear" do
    described_class.write(digest, api_key)
    described_class.clear

    expect(described_class.read(digest)).to be_nil
  end
end
