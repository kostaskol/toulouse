require "rails_helper"

RSpec.describe Shopper::Session, type: :model do
  describe "creation", :as_tenant do
    it { is_expected.to belong_to(:shopper) }

    it "uses the shopper_sessions table" do
      expect(described_class.table_name).to eq("shopper_sessions")
    end

    it "exposes a prefixed token once on the created record" do
      session = create(:shopper_session)

      expect(session.token).to start_with(described_class::TOKEN_PREFIX)
      expect(described_class.find(session.id).token).to be_nil
    end

    it "stores a digest rather than the token" do
      session = create(:shopper_session)

      expect(session.token_digest).to eq(described_class.digest(session.token))
    end

    it "shares its prefix with no other token type" do
      expect([Tenant::ApiKey::TOKEN_PREFIX, Staff::Session::TOKEN_PREFIX]).not_to include(described_class::TOKEN_PREFIX)
    end

    it "expires after the idle timeout" do
      session = create(:shopper_session)

      expect(session.expires_at).to be_within(1.second).of(described_class::IDLE_TIMEOUT.from_now)
    end
  end

  describe ".authenticate" do
    let(:tenant) { create(:tenant) }
    let!(:session) { create(:shopper_session, tenant:) }

    it "finds the session by its token within its tenant" do
      expect(as_tenant(tenant) { described_class.authenticate(session.token) }).to eq(session)
    end

    it "does not find the session from another tenant" do
      expect(as_tenant(create(:tenant)) { described_class.authenticate(session.token) }).to be_nil
    end

    it "needs a tenant" do
      expect { described_class.authenticate(session.token) }.to raise_error(Tenancy::NoTenantError)
    end

    it "rejects an unknown token" do
      token = "#{described_class::TOKEN_PREFIX}#{SecureRandom.hex}"

      expect(as_tenant(tenant) { described_class.authenticate(token) }).to be_nil
    end

    it "rejects an expired session" do
      travel described_class::IDLE_TIMEOUT + 1.second

      expect(as_tenant(tenant) { described_class.authenticate(session.token) }).to be_nil
    end

    it "rejects a staff token before querying" do
      staff_session = create(:staff_session, tenant:)

      as_tenant(tenant) do
        expect(count_queries { expect(described_class.authenticate(staff_session.token)).to be_nil }).to eq(0)
      end
    end

    it "rejects a missing token" do
      expect(as_tenant(tenant) { described_class.authenticate(nil) }).to be_nil
    end

    it "rejects bytes that are not valid text" do
      expect(as_tenant(tenant) { described_class.authenticate("#{described_class::TOKEN_PREFIX}\xff".b) }).to be_nil
    end
  end

  describe "#refresh_expiry", :as_tenant do
    let(:session) { create(:shopper_session) }

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
