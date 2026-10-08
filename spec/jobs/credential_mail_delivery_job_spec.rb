require "rails_helper"

RSpec.describe CredentialMailDeliveryJob do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:shopper) { as_tenant(tenant) { create(:shopper) } }

  before do
    stub_const("CredentialRecordingMailer", Class.new(RecordingMailer) { self.delivery_job = CredentialMailDeliveryJob })
    as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") }
    ActionMailer::Base.deliveries.clear
  end

  it "delivers for a tenant suspended after the mail was queued" do
    as_tenant(tenant) { CredentialRecordingMailer.notice(shopper).deliver_later }
    tenant.update!(status: :suspended)

    perform_enqueued_jobs

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[shopper.email]])
  end

  it "delivers for a pending tenant" do
    tenant.update!(status: :pending)
    as_tenant(tenant) { CredentialRecordingMailer.notice(shopper).deliver_later }

    perform_enqueued_jobs

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[shopper.email]])
  end

  it "drops mail whose tenant was deleted after it was queued" do
    as_tenant(tenant) { CredentialRecordingMailer.notice(shopper).deliver_later }
    tenant.destroy

    perform_enqueued_jobs

    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
