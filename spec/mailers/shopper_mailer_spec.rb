require "rails_helper"

RSpec.describe ShopperMailer do
  let(:tenant) { create(:tenant) }
  let(:email) { build(:shopper).email }

  before { as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") } }

  describe "#signup_code" do
    let(:mail) { as_tenant(tenant) { described_class.signup_code(email).deliver_now } }
    let(:code) { mail.text_part.body.to_s[/\b\d{#{Shopper::SignupCode::DIGITS}}\b/o] }

    it "goes to the email, from the store" do
      expect(mail.to).to eq([email])
      expect(mail[:from].display_names).to eq([tenant.name])
    end

    it "carries the code that is stored for the email" do
      mailed = code

      expect(as_tenant(tenant) { Shopper::SignupCode.find_by!(email:).refusal(mailed) }).to be_nil
    end

    it "keeps the code out of the subject" do
      expect(mail.subject).not_to include(code)
    end

    it "puts the same code in the HTML part" do
      expect(mail.html_part.body.to_s).to include(code)
    end
  end
end
