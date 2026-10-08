require "rails_helper"

RSpec.describe "Storefront shopper signup", type: :request do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:api_key) { create(:tenant_api_key, tenant:) }
  let(:email) { build(:shopper).email }
  let(:password) { SecureRandom.alphanumeric(16) }

  before do
    as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") }
    ActionMailer::Base.deliveries.clear
  end

  def failure(name) = V1::Storefront::SignupsController::FAILURES.fetch(name)
  def api_key_header(key = api_key) = { Tenancy::RequiresTenant::HEADER => key.token }

  def request_code(email = self.email, headers: api_key_header)
    post "/v1/storefront/signup", params: { email: }, headers:, as: :json
    perform_enqueued_jobs
  end

  def complete(code:, email: self.email, password: self.password, headers: api_key_header)
    put "/v1/storefront/signup", params: { email:, code:, password: }, headers:, as: :json
  end

  def mailed_code
    ActionMailer::Base.deliveries.last.text_part.body.to_s[/\b\d{#{Shopper::SignupCode::DIGITS}}\b/o]
  end

  def wrong(code) = ((code.to_i + 1) % (10**Shopper::SignupCode::DIGITS)).to_s.rjust(Shopper::SignupCode::DIGITS, "0")

  describe "POST /v1/storefront/signup" do
    it "accepts with no body" do
      request_code

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
    end

    it "mails a code to the email" do
      request_code

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[email]])
      expect(mailed_code).to be_present
    end

    it "refuses the email of a shopper" do
      create(:shopper, tenant:, email:)

      request_code

      expect_failure(failure(:email_taken))
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "matches a taken email regardless of case" do
      create(:shopper, tenant:, email:)

      request_code(email.upcase)

      expect_failure(failure(:email_taken))
    end

    it "refuses the email of a staff-linked shopper" do
      shopper = create(:shopper, :linked_to_staff, tenant:)

      request_code(shopper.email)

      expect_failure(failure(:email_taken))
    end

    it "refuses the email of an active member with no shopper" do
      staff = create(:staff, tenant:)

      request_code(staff.email)

      expect_failure(failure(:email_taken))
    end

    it "refuses the email of a pending member" do
      staff = create(:staff, :pending, tenant:)

      request_code(staff.email)

      expect_failure(failure(:email_taken))
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "mails a code for an email taken only in another store" do
      create(:shopper, tenant: create(:tenant), email:)

      request_code

      expect(response).to have_http_status(:accepted)
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
      session = create(:shopper_session, tenant:)
      travel Shopper::Session::IDLE_TIMEOUT + 1.second

      request_code(headers: api_key_header.merge("Authorization" => "Bearer #{session.token}"))

      expect(response).to have_http_status(:accepted)
    end

    it "requires an api key" do
      request_code(headers: {})

      expect_failure(Tenancy::RequiresTenant::FAILURES.fetch(:missing_api_key))
    end
  end

  describe "PUT /v1/storefront/signup" do
    let(:code) do
      request_code
      mailed_code
    end

    it "answers with a new session for the new shopper" do
      complete(code:)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      shopper = as_tenant(tenant) { Shopper.find_by!(email:) }
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

    it "creates a shopper who can log in with the password" do
      complete(code:)

      expect(as_tenant(tenant) { Shopper::Login.call(email:, password:).session }).to be_present
    end

    it "spends the code" do
      complete(code:)

      expect(as_tenant(tenant) { Shopper::SignupCode.exists?(email:) }).to be(false)
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

    it "refuses a wrong code" do
      complete(code: wrong(code))

      expect_failure(failure(:invalid_code))
    end

    it "refuses an expired code" do
      code
      travel Shopper::SignupCode::EXPIRY + 1.second

      complete(code:)

      expect_failure(failure(:invalid_code))
    end

    it "refuses an email with no code" do
      complete(code: "0" * Shopper::SignupCode::DIGITS)

      expect_failure(failure(:invalid_code))
    end

    it "refuses the right code once the tries are used up" do
      Shopper::SignupCode::MAX_ATTEMPTS.times { complete(code: wrong(code)) }

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

    it "refuses an email taken after the code was sent" do
      code
      create(:staff, :pending, tenant:, email:)

      complete(code:)

      expect_failure(failure(:email_taken))
      expect(as_tenant(tenant) { Shopper::SignupCode.exists?(email:) }).to be(false)
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
    end

    it "ignores a tenant_id in the body" do
      code
      other = create(:tenant)
      put "/v1/storefront/signup", params: { email:, code:, password:, tenant_id: other.id },
                                   headers: api_key_header, as: :json

      expect(response).to have_http_status(:created)
      expect(as_tenant(tenant) { Shopper.exists?(email:) }).to be(true)
    end
  end
end
