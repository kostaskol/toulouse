require "rails_helper"

RSpec.describe "Tenant resolution in the request cycle", type: :request do
  around do |example|
    with_routing do |routes|
      routes.draw do
        get "up" => "rails/health#show"
        get "probe" => "tenant_probe#show"
      end
      example.run
    end
  end

  def headers_for(key)
    { Tenancy::RequiresTenant::HEADER => key.token }
  end

  it "serves /up with no credential" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end

  it "serves /up when the credential is invalid" do
    key = create(:tenant_api_key)

    get "/up", headers: { Tenancy::RequiresTenant::HEADER => key.token_prefix }

    expect(response).to have_http_status(:ok)
  end

  it "rejects a tenant-scoped request with no credential" do
    get "/probe"

    expect(response).to have_http_status(Tenancy::RequiresTenant::FAILURES.fetch(:missing_api_key).status)
  end

  it "resolves during the request" do
    key = create(:tenant_api_key)

    get "/probe", headers: headers_for(key)

    expect(response.parsed_body["tenant_id"]).to eq(key.tenant_id)
    expect(as_tenant(key.tenant) { key.reload.last_used_at }).to be_within(5.seconds).of(Time.current)
  end

  it "does not let the resolution survive the response" do
    get "/probe", headers: headers_for(create(:tenant_api_key))

    expect(Current.resolution).to be_nil
  end

  it "does not carry one request's tenant into the next" do
    first = create(:tenant_api_key)
    second = create(:tenant_api_key)

    get "/probe", headers: headers_for(first)
    get "/probe", headers: headers_for(second)

    expect(response.parsed_body["tenant_id"]).to eq(second.tenant_id)
    expect(Current.tenant).to be_nil
  end
end
