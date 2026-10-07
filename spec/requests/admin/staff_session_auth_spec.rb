require "rails_helper"

RSpec.describe "Staff session on tenant admin endpoints", type: :request do
  around do |example|
    with_routing do |routes|
      routes.draw do
        get "admin/probe" => "admin_probe#show"
        patch "admin/probe" => "admin_probe#update"
      end
      example.run
    end
  end

  let(:tenant) { create(:tenant) }
  let(:staff_session) { create(:staff_session, tenant:) }

  it "acts as the session's staff member in the session's tenant" do
    get "/admin/probe", headers: staff_cookie(staff_session)

    expect(response.parsed_body).to eq("tenant_id" => tenant.id, "staff_id" => staff_session.staff_id)
  end

  it "ignores a tenant named by the request" do
    other = create(:tenant)
    api_key = create(:tenant_api_key, tenant: other)
    headers = staff_cookie(staff_session).merge(Tenancy::RequiresTenant::HEADER => api_key.token)

    get "/admin/probe", params: { tenant_id: other.id }, headers: headers

    expect(response.parsed_body["tenant_id"]).to eq(tenant.id)
  end

  it "moves the idle deadline forward" do
    headers = staff_cookie(staff_session)
    travel Staff::Session::IDLE_TIMEOUT / 2

    get "/admin/probe", headers: headers

    expect(as_tenant(tenant) { staff_session.reload.expires_at })
      .to be_within(1.second).of(Staff::Session::IDLE_TIMEOUT.from_now)
  end

  it "leaves no actor behind after the response" do
    get "/admin/probe", headers: staff_cookie(staff_session)

    expect(Current.user).to be_nil
    expect(Current.tenant).to be_nil
  end

  it "accepts writes from an active tenant" do
    patch "/admin/probe", params: {}, headers: staff_cookie(staff_session), as: :json

    expect(response).to have_http_status(:no_content)
  end

  it "rejects writes from a suspended tenant" do
    tenant.update!(status: "suspended")

    patch "/admin/probe", params: {}, headers: staff_cookie(staff_session), as: :json

    expect_failure(RequiresStaffSession::FAILURES.fetch(:tenant_suspended))
  end

  it "serves reads to a suspended tenant" do
    tenant.update!(status: "suspended")

    get "/admin/probe", headers: staff_cookie(staff_session)

    expect(response).to have_http_status(:ok)
  end

  it "rejects a write that is not JSON" do
    patch "/admin/probe", params: {}, headers: staff_cookie(staff_session)

    expect_failure(RequiresStaffSession::FAILURES.fetch(:unsupported_media_type))
  end
end
