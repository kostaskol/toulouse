require "rails_helper"

RSpec.describe "Platform admin storefront handoff", :platform, type: :request do
  let(:password) { SecureRandom.alphanumeric(16) }
  let(:admin) { create(:platform_admin, password:) }
  let(:tenant) { create(:tenant) }

  before { platform_log_in(admin, password:) }

  def page = Nokogiri::HTML(response.body)

  def open_storefront
    get platform_tenant_path(tenant)
    post platform_tenant_handoffs_path(tenant), params: { authenticity_token: page_authenticity_token }
  end

  context "with a primary domain" do
    let!(:domain) { create(:tenant_domain, tenant:, is_primary: true) }

    it "redirects to the storefront with a handoff to the admin's shopper" do
      open_storefront

      location = URI(response.location)
      token = location.fragment.delete_prefix("handoff=")
      expect(location.to_s).to start_with("https://#{domain.hostname}/#")
      session = Tenancy.with_tenant(tenant) { Shopper::Handoff.redeem(token) }
      expect(session.shopper.platform_admin_id).to eq(admin.id)
    end
  end

  it "shows no button without a primary domain" do
    create(:tenant_domain, tenant:)

    get platform_tenant_path(tenant)

    expect(page.at_css("form[action='#{platform_tenant_handoffs_path(tenant)}']")).to be_nil
  end

  it "links each tenant to its page" do
    tenant
    get platform_tenants_path

    expect(page.at_css("a[href='#{platform_tenant_path(tenant)}']")).to be_present
  end
end
