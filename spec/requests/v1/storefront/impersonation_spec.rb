require "rails_helper"

# Set up as the platform role, the only one that can create the admin. The
# storefront side runs as the app role, as in production.
RSpec.describe "Storefront read-only impersonation", :platform, type: :request do
  let(:tenant) { create(:tenant) }
  let!(:api_key) { create(:tenant_api_key, tenant:) }
  let(:shopper) { create(:shopper, tenant:) }
  let!(:handoff) { create(:shopper_handoff, tenant:, shopper:, impersonator_id: create(:platform_admin).id) }
  let(:session) { as_app { as_tenant(tenant) { Shopper::Handoff.redeem(handoff.token) } } }

  def headers
    { Tenancy::RequiresTenant::HEADER => api_key.token, "Authorization" => "Bearer #{session.token}" }
  end

  def as_app(&) = ApplicationRecord.connected_to(role: :writing, &)

  around do |example|
    with_routing do |routes|
      routes.draw do
        get "probe" => "shopper_probe#show"
        patch "probe" => "shopper_probe#update"
        delete "v1/storefront/session" => "v1/storefront/sessions#destroy"
        get "v1/storefront/session" => "v1/storefront/sessions#show"
      end
      example.run
    end
  end

  it "serves reads" do
    as_app { get("/probe", headers:) }

    expect(response).to have_http_status(:ok)
  end

  it "refuses writes" do
    as_app { patch("/probe", headers:) }

    expect_failure(RequiresShopperSession::FAILURES.fetch(:read_only_session))
  end

  it "signs out" do
    as_app { delete("/v1/storefront/session", headers:) }

    expect(response).to have_http_status(:no_content)
  end

  it "ends after the impersonation timeout, however much it is used" do
    session
    travel Shopper::Session::IMPERSONATION_TIMEOUT - 1.minute
    as_app { get("/probe", headers:) }
    travel 2.minutes
    as_app { get("/probe", headers:) }

    expect_failure(RequiresShopperSession::FAILURES.fetch(:invalid_session))
  end

  it "says the session is read-only" do
    as_app { get("/v1/storefront/session", headers:) }

    expect(response.parsed_body["read_only"]).to be(true)
  end
end
