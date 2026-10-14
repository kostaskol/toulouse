require "rails_helper"

RSpec.describe Staff::Removal, :as_tenant do
  let!(:owner) { create(:staff, role: "owner") }

  it "keeps a pending member's row as removed" do
    member = create(:staff, :pending)

    expect(described_class.call(member)).to be_nil
    expect(member.reload).to be_removed
  end

  context "with an active member" do
    let(:password) { SecureRandom.alphanumeric(16) }
    let(:member) { create(:staff, password:) }
    let!(:shopper) { create(:shopper, :linked_to_staff, staff: member) }

    before do
      create(:staff_session, staff: member)
      create(:shopper_session, shopper:)
      described_class.call(member)
    end

    it "keeps the row as removed, with no password" do
      expect(member.reload).to have_attributes(status: "removed", password_digest: nil)
    end

    it "ends their staff and storefront sessions" do
      expect(member.sessions).to be_empty
      expect(shopper.sessions).to be_empty
    end

    it "keeps the shopper, unlinked, signing in with the member's password" do
      expect(shopper.reload.staff_id).to be_nil
      expect(shopper.authenticate(password)).to eq(shopper)
    end
  end

  it "refuses the last owner" do
    expect(described_class.call(owner)).to eq(:last_owner)
    expect(owner.reload).to be_active
  end

  it "removes an owner while another is active" do
    create(:staff, role: "owner")

    expect(described_class.call(owner)).to be_nil
    expect(owner.reload).to be_removed
  end
end
