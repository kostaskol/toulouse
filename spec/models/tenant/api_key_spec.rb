require "rails_helper"

RSpec.describe Tenant::ApiKey, :as_tenant, type: :model do
  it { is_expected.to belong_to(:tenant) }

  describe "token generation" do
    it "starts the token with the token prefix" do
      key = create(:tenant_api_key)

      expect(key.token).to start_with(described_class::TOKEN_PREFIX)
    end

    it "keeps the token readable after a fresh load" do
      key = create(:tenant_api_key)

      expect(described_class.find(key.id).token).to eq(key.token)
    end

    it "encrypts the stored token" do
      key = create(:tenant_api_key)
      raw = ApplicationRecord.lease_connection.select_value(described_class.where(id: key.id).select(:token).to_sql)

      expect(raw).not_to include(key.token)
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

  describe "keeping the token and digest in step" do
    def other_key = create(:tenant_api_key)

    it "refuses to change the token through the model" do
      key = create(:tenant_api_key)

      expect { key.update(token: other_key.token) }.to raise_error(described_class::TokenChangeError)
    end

    it "refuses to change the digest in the database" do
      key = create(:tenant_api_key)

      expect { key.update_columns(token_digest: described_class.digest(other_key.token)) }
        .to raise_error(ActiveRecord::StatementInvalid, /cannot change/)
    end

    it "refuses to change the prefix in the database" do
      key = create(:tenant_api_key)

      expect { described_class.where(id: key.id).update_all(token_prefix: other_key.token_prefix) }
        .to raise_error(ActiveRecord::StatementInvalid, /cannot change/)
    end

    it "still updates other columns" do
      key = create(:tenant_api_key)
      name = attributes_for(:tenant_api_key)[:name]

      key.update!(name:)

      expect(key.reload.name).to eq(name)
    end

    it "lets the token be re-encrypted" do
      key = create(:tenant_api_key)

      expect { key.encrypt }.not_to raise_error
      expect(described_class.find(key.id).token).to eq(key.token)
    end
  end

  describe "#verified_token" do
    it "returns the token while it matches the digest" do
      key = create(:tenant_api_key)

      expect(described_class.find(key.id).verified_token).to eq(key.token)
    end

    it "returns nil once the stored token no longer matches" do
      key = create(:tenant_api_key)
      key.update_columns(token: other_token = create(:tenant_api_key).token)

      expect(described_class.find(key.id)).to have_attributes(token: other_token, verified_token: nil)
    end

    it "returns nil when the token cannot be decrypted" do
      key = create(:tenant_api_key)
      # Raw SQL, because every Active Record write path encrypts.
      ApplicationRecord.lease_connection.exec_update(
        "UPDATE tenant_api_keys SET token = $1 WHERE id = $2", "Store plaintext", [key.token, key.id]
      )

      expect(described_class.find(key.id).verified_token).to be_nil
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
      other = create(:tenant)

      expect {
        as_tenant(other) do
          described_class.insert!({
            tenant_id: other.id, name: "Clash",
            token: existing.token, token_prefix: existing.token_prefix, token_digest: existing.token_digest
          })
        end
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "indexes tenant_id first so tenant-filtered scans can use it" do
      index = ActiveRecord::Base.connection.indexes(:tenant_api_keys)
        .find { |i| i.columns.first == "tenant_id" && i.columns.size > 1 }

      expect(index.columns).to eq(["tenant_id", "created_at"])
    end
  end

  describe "#revoke!" do
    it "stops the key from authenticating" do
      key = create(:tenant_api_key)

      key.revoke!

      expect(described_class.authenticate(key.token)).to be_nil
    end

    it "keeps the first revocation time" do
      revoked_at = 1.hour.ago
      key = create(:tenant_api_key, revoked_at:)

      key.revoke!

      expect(key.reload.revoked_at).to be_within(1.second).of(revoked_at)
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
