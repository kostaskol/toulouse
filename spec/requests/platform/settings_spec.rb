require "rails_helper"

RSpec.describe "Platform admin tenant settings", :platform, type: :request do
  let(:password) { SecureRandom.alphanumeric(16) }
  let(:admin) { create(:platform_admin, password:) }
  let(:tenant) { create(:tenant) }

  before { platform_log_in(admin, password:) }

  def page = Nokogiri::HTML(response.body)
  def weight_required? = Tenancy.with_tenant(tenant) { tenant.setting.reload.weight_required? }

  def save(weight_required)
    get platform_tenant_path(tenant)
    patch platform_tenant_setting_path(tenant),
          params: { setting: { weight_required: }, authenticity_token: page_authenticity_token }
  end

  it "turns on the weight needed to publish" do
    save("1")

    expect(response).to redirect_to(platform_tenant_path(tenant))
    expect(weight_required?).to be(true)
  end

  it "turns it off again" do
    save("1")
    save("0")

    expect(weight_required?).to be(false)
  end

  it "shows the current value on the tenant page" do
    save("1")
    get platform_tenant_path(tenant)

    expect(page.at_css("input[type=checkbox][name='setting[weight_required]']")["checked"]).to be_present
  end
end
