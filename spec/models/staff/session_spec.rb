require "rails_helper"

RSpec.describe Staff::Session, type: :model do
  describe "creation", :as_tenant do
    it { is_expected.to belong_to(:staff) }

    it "uses the staff_sessions table" do
      expect(described_class.table_name).to eq("staff_sessions")
    end

    it "exposes a prefixed token once on the created record" do
      session = create(:staff_session)

      expect(session.token).to start_with(described_class::TOKEN_PREFIX)
      expect(described_class.find(session.id).token).to be_nil
    end

    it "stores a digest rather than the token" do
      session = create(:staff_session)

      expect(session.token_digest).to eq(described_class.digest(session.token))
    end

    it "does not share its prefix with api keys" do
      expect(described_class::TOKEN_PREFIX).not_to eq(Tenant::ApiKey::TOKEN_PREFIX)
    end

    it "expires after the idle timeout" do
      session = create(:staff_session)

      expect(session.expires_at).to be_within(1.second).of(described_class::IDLE_TIMEOUT.from_now)
    end
  end

  describe ".authenticate" do
    let(:tenant) { create(:tenant) }
    let!(:session) { create(:staff_session, tenant:) }

    it "finds the session by its token with no tenant set" do
      expect(described_class.authenticate(session.token)).to eq(session)
    end

    it "rejects an unknown token" do
      expect(described_class.authenticate("#{described_class::TOKEN_PREFIX}#{SecureRandom.hex}")).to be_nil
    end

    it "rejects an expired session" do
      travel described_class::IDLE_TIMEOUT + 1.second

      expect(described_class.authenticate(session.token)).to be_nil
    end

    it "rejects a token without the staff prefix before querying" do
      token = session.token.delete_prefix(described_class::TOKEN_PREFIX)

      expect(count_queries { expect(described_class.authenticate(token)).to be_nil }).to eq(0)
    end

    it "rejects an api key token before querying" do
      api_key = create(:tenant_api_key, tenant:)

      expect(count_queries { expect(described_class.authenticate(api_key.token)).to be_nil }).to eq(0)
    end

    it "rejects a missing token" do
      expect(described_class.authenticate(nil)).to be_nil
    end

    it "rejects bytes that are not valid text" do
      expect(described_class.authenticate("#{described_class::TOKEN_PREFIX}\xff".b)).to be_nil
    end
  end

  describe "#refresh_expiry", :as_tenant do
    let(:session) { create(:staff_session) }

    it "moves the idle deadline forward" do
      travel described_class::IDLE_TIMEOUT / 2
      session.refresh_expiry

      expect(session.reload.expires_at).to be_within(1.second).of(described_class::IDLE_TIMEOUT.from_now)
    end

    it "does not write within the refresh throttle" do
      original = session.expires_at
      travel described_class::REFRESH_THROTTLE - 1.second
      session.refresh_expiry

      expect(session.reload.expires_at).to eq(original)
    end

    it "never moves past the absolute timeout" do
      created_at = session.created_at
      travel described_class::ABSOLUTE_TIMEOUT - 1.minute
      session.refresh_expiry

      expect(session.reload.expires_at).to be_within(1.second).of(created_at + described_class::ABSOLUTE_TIMEOUT)
    end
  end
end
