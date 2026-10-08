require "rails_helper"

RSpec.describe ApplicationMailer do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:shopper) { as_tenant(tenant) { create(:shopper) } }

  before do
    as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") }
    ActionMailer::Base.deliveries.clear
  end

  it "sends from the tenant's name and sender address" do
    mail = as_tenant(tenant) { RecordingMailer.notice(shopper).deliver_now }

    expect(mail.from).to eq(["orders@shop.example.com"])
    expect(mail[:from].display_names).to eq([tenant.name])
  end

  it "refuses to send for a tenant with no sender address" do
    as_tenant(tenant) { tenant.setting.update!(sender_email: nil) }

    expect { as_tenant(tenant) { RecordingMailer.notice(shopper).deliver_now } }
      .to raise_error(ApplicationMailer::MissingSenderError)
  end

  describe "background delivery" do
    # Row-level security hides the shopper argument until its tenant is current.
    it "loads its arguments as the tenant that queued it" do
      as_tenant(tenant) { RecordingMailer.notice(shopper).deliver_later }

      perform_enqueued_jobs

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[shopper.email]])
    end

    it "drops mail whose tenant was suspended after it was queued" do
      as_tenant(tenant) { RecordingMailer.notice(shopper).deliver_later }
      tenant.update!(status: :suspended)

      perform_enqueued_jobs

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "links" do
    let(:token) { SecureRandom.urlsafe_base64 }

    def link(action, *args)
      as_tenant(tenant) { LinkMailer.public_send(action, *args).deliver_now }.body.to_s
    end

    it "points storefront links at the tenant's primary domain, with the token in the fragment" do
      domain = as_tenant(tenant) { create(:tenant_domain, is_primary: true) }

      expect(link(:storefront, "/path", token)).to eq("https://#{domain.hostname}/path##{token}")
    end

    it "refuses a storefront link for a tenant with no primary domain" do
      as_tenant(tenant) { create(:tenant_domain, is_primary: false) }

      expect { link(:storefront, "/path", token) }.to raise_error(ApplicationMailer::MissingPrimaryDomainError)
    end

    it "points admin links at the tenant admin origin, with the token in the fragment" do
      expect(link(:admin, "/path", token)).to eq("#{Rails.configuration.x.admin_origin}/path##{token}")
    end

    it "leaves out the fragment when there is no token" do
      expect(link(:admin, "/path", nil)).to eq("#{Rails.configuration.x.admin_origin}/path")
    end
  end
end
