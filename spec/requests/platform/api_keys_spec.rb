require "rails_helper"

RSpec.describe "Platform admin API keys", :platform, type: :request do
  let(:password) { SecureRandom.alphanumeric(16) }
  let(:admin) { create(:platform_admin, password:) }
  let(:tenant) { create(:tenant) }
  let(:name) { SecureRandom.alphanumeric(12) }

  before { platform_log_in(admin, password:) }

  def page = Nokogiri::HTML(response.body)
  def dom_id(record) = ActionView::RecordIdentifier.dom_id(record)
  def keys_of(tenant) = Tenancy.with_tenant(tenant) { Tenant::ApiKey.all.to_a }

  def issue(name, tenant: self.tenant)
    get platform_tenant_api_keys_path(tenant)
    post platform_tenant_api_keys_path(tenant),
         params: { api_key: { name: }, authenticity_token: page_authenticity_token }
  end

  def revoke(key)
    get platform_tenant_api_keys_path(key.tenant)
    post revoke_platform_tenant_api_key_path(key.tenant, key), params: { authenticity_token: page_authenticity_token }
  end

  describe "the tenant list" do
    it "links each tenant to its API keys" do
      tenants = create_list(:tenant, 2)

      get platform_tenants_path

      tenants.each do |tenant|
        expect(page.at_css("a[href='#{platform_tenant_api_keys_path(tenant)}']")).to be_present
      end
    end
  end

  describe "listing keys" do
    it "shows the tenant's keys by prefix, newest first" do
      older = create(:tenant_api_key, tenant:, created_at: 1.day.ago)
      newer = create(:tenant_api_key, tenant:)

      get platform_tenant_api_keys_path(tenant)

      expect(page.css("tbody tr").pluck("id")).to eq([dom_id(newer), dom_id(older)])
      expect(response.body).to include(newer.token_prefix)
    end

    it "shows neither tokens nor digests" do
      key = create(:tenant_api_key, tenant:)

      get platform_tenant_api_keys_path(tenant)

      expect(response.body).not_to include(key.token)
      expect(response.body).not_to include(key.token_digest)
    end

    it "leaves out other tenants' keys" do
      other = create(:tenant_api_key)

      get platform_tenant_api_keys_path(tenant)

      expect(response.body).not_to include(other.token_prefix)
    end

    it "answers not found for an unknown tenant" do
      get platform_tenant_api_keys_path(SecureRandom.uuid)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "issuing a key" do
    it "creates the key and shows it" do
      issue(name)

      key = keys_of(tenant).sole
      expect(response).to redirect_to(platform_tenant_api_key_path(tenant, key))
      follow_redirect!
      expect(page.at_css("#token").text).to eq(key.token)
    end

    it "issues a key that resolves the tenant" do
      issue(name)
      follow_redirect!

      expect(Tenancy::Resolver.call(page.at_css("#token").text).tenant).to eq(tenant)
    end

    it "issues keys for a tenant that is not active yet" do
      pending_tenant = create(:tenant, status: "pending")

      issue(name, tenant: pending_tenant)

      expect(keys_of(pending_tenant).size).to eq(1)
    end

    it "requires a name" do
      issue("")

      expect(response).to have_http_status(:unprocessable_content)
      expect(page.at_css("[role=alert]")).to be_present
      expect(keys_of(tenant)).to be_empty
    end

    it "rejects a request without the page's authenticity token" do
      post platform_tenant_api_keys_path(tenant), params: { api_key: { name: } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(keys_of(tenant)).to be_empty
    end
  end

  describe "revealing a key" do
    it "shows the token" do
      key = create(:tenant_api_key, tenant:)

      get platform_tenant_api_key_path(tenant, key)

      expect(page.at_css("#token").text).to eq(key.token)
    end

    it "refuses to show a stored token that no longer matches its digest" do
      key = create(:tenant_api_key, tenant:)
      drifted = create(:tenant_api_key, tenant:).token
      Tenancy.with_tenant(tenant) { key.update_columns(token: drifted) }

      get platform_tenant_api_key_path(tenant, key)

      expect(page.at_css("#token")).to be_nil
      expect(page.at_css("[role=alert]")).to be_present
      expect(response.body).not_to include(drifted)
    end

    it "tells caches not to keep the token" do
      key = create(:tenant_api_key, tenant:)

      get platform_tenant_api_key_path(tenant, key)

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "cannot reach another tenant's key through this tenant" do
      key = create(:tenant_api_key)

      get platform_tenant_api_key_path(tenant, key)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "revoking a key" do
    it "stops the key from authenticating and keeps it listed" do
      key = create(:tenant_api_key, tenant:)

      revoke(key)

      expect(response).to redirect_to(platform_tenant_api_keys_path(tenant))
      expect(Tenant::ApiKey.authenticate(key.token)).to be_nil
      follow_redirect!
      expect(page.at_css("##{dom_id(key)}").text).to include("Revoked")
    end

    it "leaves the tenant's other keys working" do
      revoked, kept = create_list(:tenant_api_key, 2, tenant:)

      revoke(revoked)

      expect(Tenant::ApiKey.authenticate(kept.token)).to eq(kept)
    end

    it "cannot reach another tenant's key through this tenant" do
      key = create(:tenant_api_key)

      get platform_tenant_api_keys_path(tenant)
      post revoke_platform_tenant_api_key_path(tenant, key), params: { authenticity_token: page_authenticity_token }

      expect(response).to have_http_status(:not_found)
      expect(Tenant::ApiKey.authenticate(key.token)).to eq(key)
    end
  end
end
