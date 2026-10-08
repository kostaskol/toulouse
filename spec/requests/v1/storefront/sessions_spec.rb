require "rails_helper"

RSpec.describe "Storefront shopper sessions", type: :request do
  let(:tenant) { create(:tenant) }
  let(:api_key) { create(:tenant_api_key, tenant:) }
  let(:password) { SecureRandom.alphanumeric(16) }
  let!(:shopper) { create(:shopper, tenant:, password:) }

  def api_key_header(key = api_key) = { Tenancy::RequiresTenant::HEADER => key.token }
  def bearer(token) = { "Authorization" => "Bearer #{token}" }

  def log_in(password: self.password, headers: api_key_header)
    post "/v1/storefront/session", params: { email: shopper.email, password: }, headers:, as: :json
  end

  describe "POST /v1/storefront/session" do
    it "opens a session and returns its token" do
      log_in

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["token"]).to start_with(Shopper::Session::TOKEN_PREFIX)
      expect(body["shopper"]).to eq("id" => shopper.id, "email" => shopper.email)
    end

    it "states when the session ends at the latest" do
      freeze_time do
        log_in

        expect(Time.iso8601(response.parsed_body["expires_at"])).to eq(Shopper::Session::ABSOLUTE_TIMEOUT.from_now)
      end
    end

    it "lets the token authenticate the next request" do
      log_in
      get "/v1/storefront/session", headers: api_key_header.merge(bearer(response.parsed_body["token"]))

      expect(response).to have_http_status(:ok)
    end

    it "refuses a wrong password" do
      log_in(password: SecureRandom.alphanumeric(16))

      expect_failure(V1::Storefront::SessionsController::FAILURES.fetch(:invalid_credentials))
    end

    it "says when the email is locked, and for how long" do
      LoginAttempt::MAX_FAILURES.times { log_in(password: SecureRandom.alphanumeric(16)) }

      expect_failure(V1::Storefront::SessionsController::FAILURES.fetch(:too_many_attempts))
      expect(response.headers["Retry-After"].to_i).to be_between(1, LoginAttempt::LOCKOUT.to_i)
    end

    it "refuses a shopper of another tenant" do
      log_in(headers: api_key_header(create(:tenant_api_key, tenant: create(:tenant))))

      expect_failure(V1::Storefront::SessionsController::FAILURES.fetch(:invalid_credentials))
    end

    it "ignores a stale session sent along" do
      session = create(:shopper_session, tenant:, shopper:)
      travel Shopper::Session::IDLE_TIMEOUT + 1.second

      log_in(headers: api_key_header.merge(bearer(session.token)))

      expect(response).to have_http_status(:created)
    end

    it "requires an api key" do
      log_in(headers: {})

      expect_failure(Tenancy::RequiresTenant::FAILURES.fetch(:missing_api_key))
    end

    it "ignores a tenant_id in the body" do
      other = create(:tenant)
      post "/v1/storefront/session", params: { email: shopper.email, password:, tenant_id: other.id },
                                     headers: api_key_header, as: :json

      expect(response).to have_http_status(:created)
      expect(as_tenant(tenant) { Shopper::Session.sole.shopper }).to eq(shopper)
    end
  end

  describe "GET /v1/storefront/session" do
    let(:session) { create(:shopper_session, tenant:, shopper:) }

    it "describes the shopper" do
      get "/v1/storefront/session", headers: api_key_header.merge(bearer(session.token))

      expect(response.parsed_body).to eq(
        "shopper" => { "id" => shopper.id, "email" => shopper.email },
        "expires_at" => session.absolute_expiry.iso8601(3)
      )
    end

    it "refuses a request with no session" do
      get "/v1/storefront/session", headers: api_key_header

      expect_failure(RequiresShopperSession::FAILURES.fetch(:missing_session))
    end

    it "refuses an expired session" do
      token = session.token
      travel Shopper::Session::IDLE_TIMEOUT + 1.second

      get "/v1/storefront/session", headers: api_key_header.merge(bearer(token))

      expect_failure(RequiresShopperSession::FAILURES.fetch(:invalid_session))
    end

    it "refuses a session from another tenant" do
      other_key = create(:tenant_api_key, tenant: create(:tenant))

      get "/v1/storefront/session", headers: api_key_header(other_key).merge(bearer(session.token))

      expect_failure(RequiresShopperSession::FAILURES.fetch(:invalid_session))
    end

    it "refuses a staff session token" do
      staff_session = create(:staff_session, tenant:)

      get "/v1/storefront/session", headers: api_key_header.merge(bearer(staff_session.token))

      expect_failure(RequiresShopperSession::FAILURES.fetch(:invalid_session))
    end

    it "refuses a credential that is not a Bearer token" do
      get "/v1/storefront/session", headers: api_key_header.merge("Authorization" => "Basic #{session.token}")

      expect_failure(RequiresShopperSession::FAILURES.fetch(:invalid_session))
    end

    it "checks the api key before the session" do
      get "/v1/storefront/session", headers: bearer(session.token)

      expect_failure(Tenancy::RequiresTenant::FAILURES.fetch(:missing_api_key))
    end

    it "is refused in tenant admin" do
      get "/admin/session", headers: { "Cookie" => "#{RequiresStaffSession::COOKIE}=#{session.token}" }

      expect_failure(RequiresStaffSession::FAILURES.fetch(:invalid_session))
    end
  end

  describe "DELETE /v1/storefront/session" do
    let(:session) { create(:shopper_session, tenant:, shopper:) }

    it "ends the session" do
      delete "/v1/storefront/session", headers: api_key_header.merge(bearer(session.token))

      expect(response).to have_http_status(:no_content)
      expect(as_tenant(tenant) { Shopper::Session.exists?(session.id) }).to be(false)
    end

    it "makes the old token useless" do
      delete "/v1/storefront/session", headers: api_key_header.merge(bearer(session.token))
      get "/v1/storefront/session", headers: api_key_header.merge(bearer(session.token))

      expect_failure(RequiresShopperSession::FAILURES.fetch(:invalid_session))
    end
  end
end
