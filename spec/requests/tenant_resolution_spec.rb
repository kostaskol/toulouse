require "rails_helper"

RSpec.describe "Tenant resolution in the request cycle", type: :request do
  it "serves /up with no credential" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end

  it "serves /up when the credential is invalid" do
    key = create(:tenant_api_key)

    get "/up", headers: { Tenancy::Resolve::HEADER => key.token_prefix }

    expect(response).to have_http_status(:ok)
  end

  it "resolves during the request" do
    key = create(:tenant_api_key)

    get "/up", headers: { Tenancy::Resolve::HEADER => key.token }

    expect(key.reload.last_used_at).to be_within(5.seconds).of(Time.current)
  end

  it "does not let the resolution survive the response" do
    key = create(:tenant_api_key)

    get "/up", headers: { Tenancy::Resolve::HEADER => key.token }

    expect(Current.resolution).to be_nil
  end

  it "does not carry one request's tenant into the next" do
    first = create(:tenant_api_key)
    second = create(:tenant_api_key)

    get "/up", headers: { Tenancy::Resolve::HEADER => first.token }
    get "/up", headers: { Tenancy::Resolve::HEADER => second.token }

    expect(second.reload.last_used_at).to be_present
    expect(Current.tenant).to be_nil
  end
end
