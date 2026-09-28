require "rails_helper"

RSpec.describe Tenancy::ResolutionCache do
  let(:api_key) { create(:tenant_api_key) }
  let(:digest) { api_key.token_digest }

  def write_entry(digest = self.digest, api_key = self.api_key)
    described_class.write(digest, api_key, generation: described_class.generation)
  end

  it "returns nil for a digest it has never seen" do
    expect(described_class.read(Tenant::ApiKey.digest(api_key.token_prefix))).to be_nil
  end

  it "reads back an entry it wrote" do
    write_entry
    entry = described_class.read(digest)

    expect(entry.api_key_id).to eq(api_key.id)
    expect(entry.last_used_at).to eq(api_key.last_used_at)
    expect(entry.tenant).to eq(api_key.tenant)
  end

  it "builds the tenant without a query" do
    write_entry
    entry = described_class.read(digest)

    expect(count_queries { entry.tenant }).to eq(0)
  end

  it "builds a tenant that is persisted and fully attributed" do
    write_entry
    tenant = described_class.read(digest).tenant

    expect(tenant).to be_persisted
    expect(tenant.status).to eq(api_key.tenant.status)
    expect(tenant.slug).to eq(api_key.tenant.slug)
  end

  it "hands out a separate tenant object per read" do
    write_entry

    first = described_class.read(digest).tenant
    second = described_class.read(digest).tenant
    first.name = first.name.reverse

    expect(first).not_to equal(second)
    expect(second.name).to eq(api_key.tenant.name)
  end

  it "keeps an entry until the TTL elapses" do
    write_entry

    travel(described_class::TTL - 1.second) do
      expect(described_class.read(digest)).not_to be_nil
    end
  end

  it "drops an entry once the TTL has elapsed" do
    write_entry

    travel(described_class::TTL + 1.second) do
      expect(described_class.read(digest)).to be_nil
    end
  end

  it "keeps entries for different digests apart" do
    other = create(:tenant_api_key)
    write_entry
    write_entry(other.token_digest, other)

    expect(described_class.read(digest).tenant).to eq(api_key.tenant)
    expect(described_class.read(other.token_digest).tenant).to eq(other.tenant)
  end

  it "drops everything on clear" do
    write_entry
    described_class.clear

    expect(described_class.read(digest)).to be_nil
  end

  describe ".touch_last_used" do
    it "stores the new timestamp so the write is not repeated" do
      write_entry
      described_class.touch_last_used(digest, described_class.read(digest))
      refreshed = described_class.read(digest)

      expect(count_queries { described_class.touch_last_used(digest, refreshed) }).to eq(0)
    end

    it "keeps the original expiry when it refreshes the timestamp" do
      write_entry
      entry = described_class.read(digest)

      described_class.touch_last_used(digest, entry)

      expect(described_class.read(digest).expires_at).to eq(entry.expires_at)
    end

    it "still expires a digest that is refreshed on every read" do
      write_entry

      travel(described_class::TTL - 1.second) do
        described_class.touch_last_used(digest, described_class.read(digest))
      end

      travel(described_class::TTL + 1.second) do
        expect(described_class.read(digest)).to be_nil
      end
    end

    it "does not resurrect an entry that was evicted" do
      write_entry
      entry = described_class.read(digest)
      described_class.clear

      described_class.touch_last_used(digest, entry)

      expect(described_class.read(digest)).to be_nil
    end
  end

  describe "a write racing an eviction" do
    it "drops a write whose lookups began before the cache was cleared" do
      generation = described_class.generation
      described_class.clear

      described_class.write(digest, api_key, generation: generation)

      expect(described_class.read(digest)).to be_nil
    end

    it "keeps a write whose lookups began after the last clear" do
      described_class.clear

      described_class.write(digest, api_key, generation: described_class.generation)

      expect(described_class.read(digest)).not_to be_nil
    end
  end

  describe "eviction" do
    it "clears when an api key is committed" do
      write_entry

      api_key.update!(revoked_at: Time.current)

      expect(described_class.read(digest)).to be_nil
    end

    it "clears when a tenant is committed" do
      write_entry

      api_key.tenant.update!(status: :suspended)

      expect(described_class.read(digest)).to be_nil
    end
  end
end
