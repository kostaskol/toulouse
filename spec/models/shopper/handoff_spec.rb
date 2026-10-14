require "rails_helper"

# Issued as the platform role, the only one that can read the admin row.
RSpec.describe Shopper::Handoff, :platform do
  let(:tenant) { create(:tenant) }
  let(:admin_id) { create(:platform_admin).id }

  before { as_tenant(tenant) }

  describe ".issue_for_admin" do
    it "creates the admin's shopper with no email or password" do
      handoff = described_class.issue_for_admin(admin_id)

      expect(handoff.shopper).to have_attributes(platform_admin_id: admin_id, email: nil, password_digest: nil)
      expect(handoff.token).to start_with(described_class::TOKEN_PREFIX)
    end

    it "reuses the admin's shopper" do
      first = described_class.issue_for_admin(admin_id)

      expect(described_class.issue_for_admin(admin_id).shopper).to eq(first.shopper)
    end
  end

  describe ".redeem" do
    let(:handoff) { described_class.issue_for_admin(admin_id) }

    it "opens a session for the shopper" do
      expect(described_class.redeem(handoff.token).shopper).to eq(handoff.shopper)
    end

    it "accepts a token once" do
      described_class.redeem(handoff.token)

      expect(described_class.redeem(handoff.token)).to be_nil
    end

    it "refuses an expired token" do
      token = handoff.token
      travel described_class::IDLE_TIMEOUT + 1.second

      expect(described_class.redeem(token)).to be_nil
    end

    it "refuses another token type" do
      expect(described_class.redeem(create(:shopper_session).token)).to be_nil
    end
  end
end
