require "rails_helper"

RSpec.describe "Storefront handoffs", type: :request do
  let(:tenant) { create(:tenant) }
  let(:shopper) { create(:shopper, tenant:) }
  let(:handoff) { create(:shopper_handoff, tenant:, shopper:) }

  def redeem(token, tenant: self.tenant)
    headers = { Tenancy::RequiresTenant::HEADER => create(:tenant_api_key, tenant:).token }
    post "/v1/storefront/handoff", params: { token: }, headers:, as: :json
  end

  it "opens a session for the handoff's shopper" do
    redeem(handoff.token)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["token"]).to start_with(Shopper::Session::TOKEN_PREFIX)
    expect(response.parsed_body["shopper"]).to eq("id" => shopper.id, "email" => shopper.email)
  end

  it "refuses a token used once already" do
    redeem(handoff.token)
    redeem(handoff.token)

    expect_failure(V1::Storefront::HandoffsController::FAILURES.fetch(:invalid_handoff))
  end

  it "refuses a token issued for another tenant" do
    redeem(handoff.token, tenant: create(:tenant))

    expect_failure(V1::Storefront::HandoffsController::FAILURES.fetch(:invalid_handoff))
  end
end
