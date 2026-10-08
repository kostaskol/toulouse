require "rails_helper"

RSpec.describe "Tenant admin password reset", type: :request do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:old_password) { SecureRandom.alphanumeric(16) }
  let(:new_password) { SecureRandom.alphanumeric(16) }
  let!(:staff) { create(:staff, tenant:, password: old_password) }

  before do
    as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") }
    ActionMailer::Base.deliveries.clear
  end

  def request_reset(slug: tenant.slug, email: staff.email)
    post "/admin/password_reset", params: { slug:, email: }, as: :json
    perform_enqueued_jobs
  end

  def complete_reset(token:, slug: tenant.slug, password: new_password)
    put "/admin/password_reset", params: { slug:, token:, password: }, as: :json
  end

  def reset_token(member = staff)
    as_tenant(member.tenant) { member.reload.password_reset_token }
  end

  def log_in(password)
    post "/admin/session", params: { slug: tenant.slug, email: staff.email, password: }, as: :json
  end

  describe "POST /admin/password_reset" do
    it "mails the member and accepts" do
      request_reset

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[staff.email]])
    end

    it "matches the email regardless of case" do
      request_reset(email: staff.email.upcase)

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[staff.email]])
    end

    it "answers alike and mails nobody for an unknown email" do
      request_reset(email: build(:staff).email)

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "answers alike and mails nobody for an unknown store" do
      request_reset(slug: "#{tenant.slug}-missing")

      expect(response).to have_http_status(:accepted)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "mails nobody for a member of another store" do
      other = create(:staff, tenant: create(:tenant))

      request_reset(email: other.email)

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "mails pending staff nothing, since they set a password through their invite" do
      pending = create(:staff, :pending, tenant:)

      request_reset(email: pending.email)

      expect(response).to have_http_status(:accepted)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "mails a member of a suspended store" do
      tenant.update!(status: "suspended")

      request_reset

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[staff.email]])
    end

    it "refuses a body that is not JSON" do
      post "/admin/password_reset", params: { slug: tenant.slug, email: staff.email }

      expect_failure(RequiresStaffSession::FAILURES.fetch(:unsupported_media_type))
    end
  end

  describe "PUT /admin/password_reset" do
    def invalid_token = Admin::PasswordResetsController::FAILURES.fetch(:invalid_token)
    def invalid_password = Admin::PasswordResetsController::FAILURES.fetch(:invalid_password)

    it "answers with the new session, as login does" do
      complete_reset(token: reset_token)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("staff", "id")).to eq(staff.id)
      expect(response.parsed_body.dig("tenant", "slug")).to eq(tenant.slug)
    end

    it "lets the session cookie authenticate the next request" do
      complete_reset(token: reset_token)
      get "/admin/session"

      expect(response).to have_http_status(:ok)
    end

    it "replaces the old password" do
      complete_reset(token: reset_token)

      log_in(old_password)
      expect(response).to have_http_status(:unauthorized)

      log_in(new_password)
      expect(response).to have_http_status(:created)
    end

    it "ends the member's other sessions" do
      old_session = create(:staff_session, tenant:, staff:)

      complete_reset(token: reset_token)

      expect(as_tenant(tenant) { Staff::Session.exists?(old_session.id) }).to be(false)
    end

    it "ends the linked shopper's storefront sessions" do
      shopper = create(:shopper, :linked_to_staff, tenant:, staff:)
      storefront_session = create(:shopper_session, tenant:, shopper:)

      complete_reset(token: reset_token)

      expect(as_tenant(tenant) { Shopper::Session.exists?(storefront_session.id) }).to be(false)
    end

    it "lifts a login lock on the email" do
      LoginAttempt::MAX_FAILURES.times { log_in(SecureRandom.alphanumeric(16)) }

      complete_reset(token: reset_token)
      log_in(new_password)

      expect(response).to have_http_status(:created)
    end

    it "refuses a token that was already used" do
      token = reset_token
      complete_reset(token:)

      complete_reset(token:, password: SecureRandom.alphanumeric(16))

      expect_failure(invalid_token)
    end

    it "refuses an expired token" do
      token = reset_token
      travel staff.password_reset_token_expires_in + 1.second

      complete_reset(token:)

      expect_failure(invalid_token)
    end

    it "refuses a token that is not one" do
      complete_reset(token: SecureRandom.urlsafe_base64)

      expect_failure(invalid_token)
    end

    it "refuses a token sent with another store's slug" do
      other_tenant = create(:tenant)

      complete_reset(token: reset_token, slug: other_tenant.slug)

      expect_failure(invalid_token)
    end

    it "refuses a token for another store's member" do
      other = create(:staff, tenant: create(:tenant))

      complete_reset(token: reset_token(other))

      expect_failure(invalid_token)
    end

    it "refuses an unknown store" do
      complete_reset(token: reset_token, slug: "#{tenant.slug}-missing")

      expect_failure(invalid_token)
    end

    it "refuses pending staff" do
      pending = create(:staff, :pending, tenant:)

      complete_reset(token: reset_token(pending))

      expect_failure(invalid_token)
    end

    it "refuses a blank password and keeps the token usable" do
      token = reset_token

      complete_reset(token:, password: "")
      expect_failure(invalid_password)

      complete_reset(token:)
      expect(response).to have_http_status(:created)
    end

    it "refuses a password longer than bcrypt accepts" do
      too_long = "a" * (ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED + 1)

      complete_reset(token: reset_token, password: too_long)

      expect_failure(invalid_password)
    end

    it "resets a member of a suspended store" do
      tenant.update!(status: "suspended")

      complete_reset(token: reset_token)

      expect(response).to have_http_status(:created)
    end

    it "accepts the token from the emailed link" do
      request_reset
      token = URI(ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{https?://\S+}]).fragment

      complete_reset(token:)

      expect(response).to have_http_status(:created)
    end
  end
end
