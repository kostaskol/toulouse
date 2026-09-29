require "rails_helper"

RSpec.describe Tenant::ApiKey, type: :model do
  it { is_expected.to belong_to(:tenant) }

  describe "token generation" do
    it "exposes the plaintext token once on the created record" do
      key = create(:tenant_api_key)

      expect(key.token).to start_with("tou_")
    end

    it "has no column to persist the plaintext token in" do
      expect(described_class.column_names).not_to include("token")
    end

    # reload keeps instance variables, so the token must be read from a fresh load.
    it "never persists the plaintext token" do
      key = create(:tenant_api_key)

      expect(described_class.find(key.id).token).to be_nil
    end

    it "stores a digest rather than the token" do
      key = create(:tenant_api_key)

      expect(key.token_digest).to eq(described_class.digest(key.token))
      expect(key.token_digest).not_to include(key.token)
    end

    it "shows a fixed number of random characters after the token prefix" do
      key = create(:tenant_api_key)
      shown = key.token_prefix.delete_prefix(described_class::TOKEN_PREFIX)

      expect(key.token_prefix).to start_with(described_class::TOKEN_PREFIX)
      expect(shown.length).to eq(described_class::DISPLAY_CHARS)
    end

    it "stores a display prefix that cannot be used to authenticate" do
      key = create(:tenant_api_key)

      expect(described_class.authenticate(key.token_prefix)).to be_nil
    end

    it "generates a different token for every key" do
      digests = Array.new(3) { create(:tenant_api_key).token_digest }

      expect(digests.uniq.size).to eq(3)
    end
  end

  describe ".authenticate" do
    it "returns the key matching the token" do
      key = create(:tenant_api_key)

      expect(described_class.authenticate(key.token)).to eq(key)
    end

    it "returns nil for an unknown token" do
      expect(described_class.authenticate("tou_nonsense")).to be_nil
    end

    it "returns nil for a blank token" do
      expect(described_class.authenticate(nil)).to be_nil
    end

    it "returns nil for a revoked key" do
      key = create(:tenant_api_key, revoked_at: 1.minute.ago)

      expect(described_class.authenticate(key.token)).to be_nil
    end

    it "returns nil for an expired key" do
      key = create(:tenant_api_key, expires_at: 1.minute.ago)

      expect(described_class.authenticate(key.token)).to be_nil
    end

    it "returns a key whose expiry is in the future" do
      key = create(:tenant_api_key, expires_at: 1.hour.from_now)

      expect(described_class.authenticate(key.token)).to eq(key)
    end
  end

  describe "database constraints" do
    it "rejects a duplicate token digest across tenants" do
      existing = create(:tenant_api_key)

      expect {
        described_class.insert!({
          tenant_id: create(:tenant).id, name: "Clash",
          token_prefix: "tou_clash00", token_digest: existing.token_digest
        })
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "indexes tenant_id first so tenant-filtered scans can use it" do
      index = ActiveRecord::Base.connection.indexes(:tenant_api_keys)
        .find { |i| i.columns.first == "tenant_id" && i.columns.size > 1 }

      expect(index.columns).to eq([ "tenant_id", "created_at" ])
    end
  end

  describe "#touch_last_used" do
    it "treats a null timestamp as stale and writes" do
      key = create(:tenant_api_key)

      key.touch_last_used

      expect(key.reload.last_used_at).to be_within(5.seconds).of(Time.current)
    end

    it "writes when the timestamp is older than the throttle" do
      key = create(:tenant_api_key, last_used_at: (described_class::LAST_USED_THROTTLE + 1.second).ago)

      key.touch_last_used

      expect(key.reload.last_used_at).to be_within(5.seconds).of(Time.current)
    end

    it "does not write inside the throttle window" do
      recent = (described_class::LAST_USED_THROTTLE - 1.second).ago
      key = create(:tenant_api_key, last_used_at: recent)

      key.touch_last_used

      expect(key.reload.last_used_at).to be_within(1.second).of(recent)
    end

    it "issues no query inside the throttle window" do
      key = create(:tenant_api_key, last_used_at: Time.current)

      expect(count_queries { key.touch_last_used }).to eq(0)
    end
  end
end
