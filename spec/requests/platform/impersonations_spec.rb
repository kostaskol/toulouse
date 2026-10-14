require "rails_helper"

RSpec.describe "Platform admin read-only impersonation", :platform, type: :request do
  let(:password) { SecureRandom.alphanumeric(16) }
  let(:admin) { create(:platform_admin, password:) }
  let(:tenant) { create(:tenant) }
  let!(:domain) { create(:tenant_domain, tenant:, is_primary: true) }

  before { platform_log_in(admin, password:) }

  def page = Nokogiri::HTML(response.body)

  def impersonate(email)
    get platform_tenant_path(tenant)
    post platform_tenant_impersonations_path(tenant), params: { authenticity_token: page_authenticity_token, email: }
  end

  it "opens a read-only session as the shopper with the email" do
    shopper = create(:shopper, tenant:)

    impersonate(shopper.email.upcase)

    expect(response.location).to start_with("#{domain.url}/#handoff=")
    token = URI(response.location).fragment.delete_prefix("handoff=")
    session = Tenancy.with_tenant(tenant) { Shopper::Handoff.redeem(token) }
    expect(session).to have_attributes(shopper:, impersonator_id: admin.id)
  end

  it "shows an error for an unknown email" do
    impersonate(build(:shopper).email)

    expect(response).to have_http_status(:unprocessable_content)
    expect(page.text).to include("No shopper has this email.")
  end
end
