require "rails_helper"

RSpec.describe StaffMailer do
  let(:tenant) { create(:tenant) }
  let(:staff) { create(:staff, tenant:) }

  before { as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") } }

  describe "#password_reset" do
    let(:mail) { as_tenant(tenant) { described_class.password_reset(staff).deliver_now } }
    let(:link) { URI(mail.text_part.body.to_s[%r{https?://\S+}]) }

    it "goes to the member" do
      expect(mail.to).to eq([staff.email])
    end

    it "links to the reset page in tenant admin, naming the store" do
      admin_origin = URI(Rails.configuration.x.admin_origin)

      expect([link.scheme, link.host, link.path]).to eq([admin_origin.scheme, admin_origin.host,
                                                         described_class::PASSWORD_RESET_PATH])
      expect(Rack::Utils.parse_query(link.query)).to eq("slug" => tenant.slug)
    end

    it "carries a reset token for the member in the fragment" do
      expect(as_tenant(tenant) { Staff.find_by_password_reset_token(link.fragment) }).to eq(staff)
    end

    it "puts the same link in the HTML part" do
      expect(mail.html_part.body.to_s).to include(CGI.escapeHTML(link.to_s))
    end
  end

  describe "#invite" do
    let(:staff) { create(:staff, :pending, tenant:, invited_at: Time.current) }
    let(:mail) { as_tenant(tenant) { described_class.invite(staff).deliver_now } }
    let(:link) { URI(mail.text_part.body.to_s[%r{https?://\S+}]) }

    it "goes to the invited email" do
      expect(mail.to).to eq([staff.email])
    end

    it "links to the invite page in tenant admin, naming the store" do
      admin_origin = URI(Rails.configuration.x.admin_origin)

      expect([link.scheme, link.host, link.path]).to eq([admin_origin.scheme, admin_origin.host,
                                                         described_class::INVITE_PATH])
      expect(Rack::Utils.parse_query(link.query)).to eq("slug" => tenant.slug)
    end

    it "carries an invite token for the member in the fragment" do
      expect(as_tenant(tenant) { Staff.find_by_token_for(:invite, link.fragment) }).to eq(staff)
    end

    it "puts the same link in the HTML part" do
      expect(mail.html_part.body.to_s).to include(CGI.escapeHTML(link.to_s))
    end
  end
end
