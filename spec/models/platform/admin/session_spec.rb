require "rails_helper"

RSpec.describe Platform::Admin::Session, :platform, type: :model do
  it { is_expected.to belong_to(:admin) }

  it "uses the admin_sessions table in the platform schema" do
    expect(described_class.table_name).to eq("platform.admin_sessions")
  end

  describe "creation" do
    let(:session) { create(:platform_admin_session) }

    it "exposes a prefixed token once on the created record" do
      expect(session.token).to start_with(described_class::TOKEN_PREFIX)
      expect(described_class.find(session.id).token).to be_nil
    end

    it "stores a digest rather than the token" do
      expect(session.token_digest).to eq(described_class.digest(session.token))
    end

    it "shares its prefix with no other token type" do
      expect([Staff::Session::TOKEN_PREFIX, Tenant::ApiKey::TOKEN_PREFIX]).not_to include(described_class::TOKEN_PREFIX)
    end

    it "expires after the idle timeout" do
      expect(session.expires_at).to be_within(1.second).of(described_class::IDLE_TIMEOUT.from_now)
    end
  end

  describe ".authenticate" do
    let!(:session) { create(:platform_admin_session) }

    it "finds the session by its token" do
      expect(described_class.authenticate(session.token)).to eq(session)
    end

    it "rejects an unknown token" do
      expect(described_class.authenticate("#{described_class::TOKEN_PREFIX}#{SecureRandom.hex}")).to be_nil
    end

    it "rejects an expired session" do
      travel described_class::IDLE_TIMEOUT + 1.second

      expect(described_class.authenticate(session.token)).to be_nil
    end

    it "rejects a staff session token before querying" do
      token = "#{Staff::Session::TOKEN_PREFIX}#{SecureRandom.hex}"

      expect(count_queries { expect(described_class.authenticate(token)).to be_nil }).to eq(0)
    end

    it "rejects a missing token" do
      expect(described_class.authenticate(nil)).to be_nil
    end

    it "rejects bytes that are not valid text" do
      expect(described_class.authenticate("#{described_class::TOKEN_PREFIX}\xff".b)).to be_nil
    end
  end

  describe "#refresh_expiry" do
    let(:session) { create(:platform_admin_session) }

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
