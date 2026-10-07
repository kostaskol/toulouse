require "rails_helper"

RSpec.describe "Tenant admin sessions", type: :request do
  let(:tenant) { create(:tenant) }
  let(:password) { SecureRandom.alphanumeric(16) }
  let!(:staff) { create(:staff, tenant:, password:) }

  def log_in(password: self.password)
    post "/admin/session", params: { slug: tenant.slug, email: staff.email, password: }, as: :json
  end

  describe "POST /admin/session" do
    it "opens a session and describes it" do
      log_in

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq(
        "staff" => {
          "id" => staff.id, "email" => staff.email, "role" => staff.role, "permissions" => staff.permissions.map(&:to_s)
        },
        "tenant" => { "name" => tenant.name, "slug" => tenant.slug, "status" => tenant.status }
      )
    end

    it "sets the session cookie for tenant admin paths only" do
      log_in

      expect(session_set_cookie).to include("path=#{RequiresStaffSession::COOKIE_PATH}")
      expect(session_set_cookie).to match(/httponly/i).and match(/samesite=strict/i)
      expect(session_set_cookie).not_to match(/domain=/i)
    end

    it "expires the cookie at the absolute timeout" do
      freeze_time do
        log_in

        expires = Time.httpdate(session_set_cookie[/expires=([^;]+)/i, 1])
        expect(expires).to be_within(1.second).of(Staff::Session::ABSOLUTE_TIMEOUT.from_now)
      end
    end

    it "lets the cookie authenticate the next request" do
      log_in
      get "/admin/session"

      expect(response).to have_http_status(:ok)
    end

    it "refuses a wrong password" do
      log_in(password: SecureRandom.alphanumeric(16))

      expect_failure(Admin::SessionsController::FAILURES.fetch(:invalid_credentials))
      expect(session_set_cookie).to be_nil
    end

    it "says when the email is locked, and for how long" do
      LoginAttempt::MAX_FAILURES.times { log_in(password: SecureRandom.alphanumeric(16)) }

      expect_failure(Admin::SessionsController::FAILURES.fetch(:too_many_attempts))
      expect(response.headers["Retry-After"].to_i).to be_between(1, LoginAttempt::LOCKOUT.to_i)
    end

    it "refuses a request with no credentials" do
      post "/admin/session", params: {}, as: :json

      expect_failure(Admin::SessionsController::FAILURES.fetch(:invalid_credentials))
    end

    it "refuses a body that is not JSON" do
      post "/admin/session", params: { slug: tenant.slug, email: staff.email, password: }

      expect_failure(RequiresStaffSession::FAILURES.fetch(:unsupported_media_type))
    end

    it "logs in to a suspended tenant" do
      tenant.update!(status: "suspended")
      log_in

      expect(response).to have_http_status(:created)
    end
  end

  describe "GET /admin/session" do
    let(:staff_session) { create(:staff_session, tenant:, staff:) }

    it "describes the session" do
      get "/admin/session", headers: staff_cookie(staff_session)

      expect(response.parsed_body.dig("staff", "id")).to eq(staff.id)
    end

    it "lists what the member's role permits" do
      owner = create(:staff, tenant:, role: "owner")

      get "/admin/session", headers: staff_cookie(create(:staff_session, tenant:, staff: owner))

      expect(response.parsed_body.dig("staff", "permissions")).to match_array(owner.permissions.map(&:to_s))
    end

    it "refuses a request with no cookie" do
      get "/admin/session"

      expect_failure(RequiresStaffSession::FAILURES.fetch(:missing_session))
    end

    it "does not accept an api key in place of the cookie" do
      get "/admin/session", headers: { Tenancy::RequiresTenant::HEADER => create(:tenant_api_key, tenant:).token }

      expect_failure(RequiresStaffSession::FAILURES.fetch(:missing_session))
    end

    it "refuses an expired session and drops its cookie" do
      token = staff_session.token
      travel Staff::Session::IDLE_TIMEOUT + 1.second

      get "/admin/session", headers: { "Cookie" => "#{RequiresStaffSession::COOKIE}=#{token}" }

      expect_failure(RequiresStaffSession::FAILURES.fetch(:invalid_session))
      expect(session_set_cookie).to match(/max-age=0|expires=Thu, 01 Jan 1970/i)
    end

    it "refuses an api key sent as the cookie" do
      key = create(:tenant_api_key, tenant:)

      get "/admin/session", headers: { "Cookie" => "#{RequiresStaffSession::COOKIE}=#{key.token}" }

      expect_failure(RequiresStaffSession::FAILURES.fetch(:invalid_session))
    end

    it "shows a suspended tenant's status" do
      tenant.update!(status: "suspended")

      get "/admin/session", headers: staff_cookie(staff_session)

      expect(response.parsed_body.dig("tenant", "status")).to eq("suspended")
    end
  end

  describe "DELETE /admin/session" do
    let(:staff_session) { create(:staff_session, tenant:, staff:) }

    it "ends the session" do
      delete "/admin/session", headers: staff_cookie(staff_session)

      expect(response).to have_http_status(:no_content)
      expect(as_tenant(tenant) { Staff::Session.exists?(staff_session.id) }).to be(false)
    end

    it "makes the old cookie useless" do
      delete "/admin/session", headers: staff_cookie(staff_session)
      get "/admin/session", headers: staff_cookie(staff_session)

      expect_failure(RequiresStaffSession::FAILURES.fetch(:invalid_session))
    end

    it "logs out of a suspended tenant" do
      tenant.update!(status: "suspended")

      delete "/admin/session", headers: staff_cookie(staff_session)

      expect(response).to have_http_status(:no_content)
    end
  end
end
