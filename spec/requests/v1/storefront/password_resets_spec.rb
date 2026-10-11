require "rails_helper"

RSpec.describe "Storefront shopper password reset", type: :request do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:api_key) { create(:tenant_api_key, tenant:) }
  let(:password) { SecureRandom.alphanumeric(16) }
  let!(:shopper) { create(:shopper, tenant:) }

  before do
    as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") }
    ActionMailer::Base.deliveries.clear
  end

  def email = shopper.email
  def old_password = shopper.password
  def failure(name) = V1::Storefront::PasswordResetsController::FAILURES.fetch(name)
  def api_key_header(key = api_key) = { Tenancy::RequiresTenant::HEADER => key.token }

  def request_code(email = self.email, headers: api_key_header)
    post "/v1/storefront/password_reset", params: { email: }, headers:, as: :json
    perform_enqueued_jobs
  end

  def complete(code:, email: self.email, password: self.password, headers: api_key_header)
    put "/v1/storefront/password_reset", params: { email:, code:, password: }, headers:, as: :json
  end

  def mailed_code
    ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{#{Shopper::EmailCode::DIGITS}}\b/o]
  end

  def wrong(code) = ((code.to_i + 1) % (10**Shopper::EmailCode::DIGITS)).to_s.rjust(Shopper::EmailCode::DIGITS, "0")

  def log_in(password) = as_tenant(tenant) { Shopper::Login.call(email:, password:).session }

  describe "POST /v1/storefront/password_reset" do
    it "accepts with no body" do
      request_code

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
    end

    it "mails a code to the shopper" do
      request_code

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[email]])
      expect(mailed_code).to be_present
    end

    it "matches the email regardless of case" do
      request_code(email.upcase)

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[email]])
    end

    it "mails a staff-linked shopper the tenant admin reset link" do
      linked = create(:shopper, :linked_to_staff, tenant:)

      request_code(linked.email)

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[linked.email]])
      expect(ActionMailer::Base.deliveries.last.text_part.body.to_s).to include(StaffMailer::PASSWORD_RESET_PATH)
    end

    it "answers alike and issues no code for a staff-linked shopper" do
      linked = create(:shopper, :linked_to_staff, tenant:)

      request_code(linked.email)

      expect(response).to have_http_status(:accepted)
      expect(as_tenant(tenant) { Shopper::EmailCode.exists?(email: linked.email) }).to be(false)
    end

    it "mails a code to a shopper who shares the email of a pending member" do
      create(:staff, :pending, tenant:, email:)

      request_code

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[email]])
      expect(mailed_code).to be_present
    end

    it "answers alike and mails nobody for an unknown email" do
      request_code(build(:shopper).email)

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "answers alike and mails nobody for a pending member" do
      staff = create(:staff, :pending, tenant:)

      request_code(staff.email)

      expect(response).to have_http_status(:accepted)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "answers alike and mails nobody for a shopper of another store" do
      other = create(:shopper, tenant: create(:tenant))

      request_code(other.email)

      expect(response).to have_http_status(:accepted)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "refuses a malformed email" do
      request_code("not-an-email")

      expect_failure(failure(:invalid_email))
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "refuses a blank email" do
      request_code("")

      expect_failure(failure(:invalid_email))
    end

    it "ignores a stale session sent along" do
      session = create(:shopper_session, tenant:, shopper:)
      travel Shopper::Session::IDLE_TIMEOUT + 1.second

      request_code(headers: api_key_header.merge("Authorization" => "Bearer #{session.token}"))

      expect(response).to have_http_status(:accepted)
    end

    it "requires an api key" do
      request_code(headers: {})

      expect_failure(Tenancy::RequiresTenant::FAILURES.fetch(:missing_api_key))
    end
  end

  describe "PUT /v1/storefront/password_reset" do
    let(:code) do
      request_code
      mailed_code
    end

    it "answers with a new session for the shopper" do
      complete(code:)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["token"]).to start_with(Shopper::Session::TOKEN_PREFIX)
      expect(body["shopper"]).to eq("id" => shopper.id, "email" => email)
    end

    it "states when the session ends at the latest" do
      code
      freeze_time do
        complete(code:)

        expect(Time.iso8601(response.parsed_body["expires_at"])).to eq(Shopper::Session::ABSOLUTE_TIMEOUT.from_now)
      end
    end

    it "lets the token authenticate the next request" do
      complete(code:)
      get "/v1/storefront/session",
          headers: api_key_header.merge("Authorization" => "Bearer #{response.parsed_body["token"]}")

      expect(response).to have_http_status(:ok)
    end

    it "replaces the password" do
      complete(code:)

      expect(log_in(password)).to be_present
      expect(log_in(old_password)).to be_nil
    end

    it "ends every earlier session" do
      old_session = create(:shopper_session, tenant:, shopper:)

      complete(code:)

      expect(as_tenant(tenant) { Shopper::Session.exists?(old_session.id) }).to be(false)
    end

    it "spends the code" do
      complete(code:)

      expect(as_tenant(tenant) { Shopper::EmailCode.exists?(email:) }).to be(false)
    end

    it "lifts a login lock on the email" do
      as_tenant(tenant) { LoginAttempt::MAX_FAILURES.times { LoginAttempt.record_failure(email) } }

      complete(code:)

      expect(as_tenant(tenant) { LoginAttempt.locked_until(email) }).to be_nil
    end

    it "matches the email regardless of case" do
      complete(code:, email: email.upcase)

      expect(response).to have_http_status(:created)
    end

    it "refuses a code already used" do
      complete(code:)

      complete(code:, password: SecureRandom.alphanumeric(16))

      expect_failure(failure(:invalid_code))
    end

    it "refuses a wrong code" do
      complete(code: wrong(code))

      expect_failure(failure(:invalid_code))
    end

    it "refuses an expired code" do
      code
      travel Shopper::EmailCode::EXPIRY + 1.second

      complete(code:)

      expect_failure(failure(:invalid_code))
    end

    it "refuses an email with no code" do
      complete(code: "0" * Shopper::EmailCode::DIGITS)

      expect_failure(failure(:invalid_code))
    end

    it "refuses the right code once the tries are used up" do
      Shopper::EmailCode::MAX_ATTEMPTS.times { complete(code: wrong(code)) }

      complete(code:)

      expect_failure(failure(:invalid_code))
    end

    it "refuses a code replaced by a newer request" do
      old_code = code
      # A new code can repeat the old one by chance.
      request_code while mailed_code == old_code

      complete(code: old_code)

      expect_failure(failure(:invalid_code))
    end

    it "refuses a code sent by another store" do
      code
      other_key = create(:tenant_api_key, tenant: create(:tenant))

      complete(code:, headers: api_key_header(other_key))

      expect_failure(failure(:invalid_code))
    end

    it "refuses a signup code" do
      signup_code = as_tenant(tenant) { Shopper::EmailCode.issue(email, purpose: :signup) }

      complete(code: signup_code)

      expect_failure(failure(:invalid_code))
    end

    it "refuses a shopper linked to staff after the code was sent" do
      code
      as_tenant(tenant) { shopper.update!(staff: create(:staff, tenant:, email:), password_digest: nil) }

      complete(code:)

      expect_failure(failure(:invalid_code))
      expect(as_tenant(tenant) { Shopper::EmailCode.exists?(email:) }).to be(false)
    end

    it "refuses a blank password and keeps the code" do
      complete(code:, password: "")

      expect_failure(failure(:invalid_password))
      complete(code:)
      expect(response).to have_http_status(:created)
    end

    it "refuses a password longer than bcrypt allows" do
      complete(code:, password: "a" * (ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED + 1))

      expect_failure(failure(:invalid_password))
      expect(log_in(old_password)).to be_present
    end
  end
end
