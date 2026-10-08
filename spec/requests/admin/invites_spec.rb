require "rails_helper"

RSpec.describe "Tenant admin invite acceptance", type: :request do
  let(:tenant) { create(:tenant) }
  let(:password) { SecureRandom.alphanumeric(16) }
  let!(:staff) { create(:staff, :pending, tenant:, invited_at: Time.current) }

  def invalid_token = Admin::InvitesController::FAILURES.fetch(:invalid_token)
  def invalid_password = Admin::InvitesController::FAILURES.fetch(:invalid_password)

  def accept(token:, slug: tenant.slug, password: self.password)
    put "/admin/invite", params: { slug:, token:, password: }, as: :json
  end

  def invite_token(member = staff)
    as_tenant(member.tenant) { member.reload.generate_token_for(:invite) }
  end

  def log_in(password)
    post "/admin/session", params: { slug: tenant.slug, email: staff.email, password: }, as: :json
  end

  it "answers with the new session, as login does" do
    accept(token: invite_token)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("staff", "id")).to eq(staff.id)
    expect(response.parsed_body.dig("tenant", "slug")).to eq(tenant.slug)
  end

  it "lets the session cookie authenticate the next request" do
    accept(token: invite_token)
    get "/admin/session"

    expect(response).to have_http_status(:ok)
  end

  it "activates the member with the new password" do
    accept(token: invite_token)
    log_in(password)

    expect(response).to have_http_status(:created)
    expect(as_tenant(tenant) { staff.reload.status }).to eq("active")
  end

  it "lifts a login lock on the email" do
    LoginAttempt::MAX_FAILURES.times { log_in(SecureRandom.alphanumeric(16)) }

    accept(token: invite_token)
    log_in(password)

    expect(response).to have_http_status(:created)
  end

  context "when no shopper has the email" do
    it "creates the linked shopper" do
      accept(token: invite_token)

      shopper = as_tenant(tenant) { Shopper.find_by(email: staff.email) }
      expect(shopper).to have_attributes(staff_id: staff.id, password_digest: nil)
      expect(response.parsed_body["shopper_merged"]).to be(false)
    end
  end

  context "when a shopper has the email" do
    let(:shopper_password) { SecureRandom.alphanumeric(16) }
    let!(:shopper) { create(:shopper, tenant:, email: staff.email, password: shopper_password) }

    it "links that shopper and says so" do
      accept(token: invite_token)

      expect(as_tenant(tenant) { shopper.reload.staff_id }).to eq(staff.id)
      expect(response.parsed_body["shopper_merged"]).to be(true)
    end

    it "removes the shopper's own password" do
      accept(token: invite_token)

      expect(as_tenant(tenant) { shopper.reload.password_digest }).to be_nil
      expect(as_tenant(tenant) { Shopper::Login.call(email: staff.email, password: shopper_password).failure })
        .to eq(:invalid_credentials)
    end

    it "ends the shopper's storefront sessions" do
      storefront_session = create(:shopper_session, tenant:, shopper:)

      accept(token: invite_token)

      expect(as_tenant(tenant) { Shopper::Session.exists?(storefront_session.id) }).to be(false)
    end
  end

  it "refuses a token that was already used" do
    token = invite_token
    accept(token:)

    accept(token:, password: SecureRandom.alphanumeric(16))

    expect_failure(invalid_token)
  end

  it "refuses an expired token" do
    token = invite_token
    travel Staff::INVITE_EXPIRY + 1.second

    accept(token:)

    expect_failure(invalid_token)
  end

  it "refuses a token replaced by a newer invite" do
    token = invite_token
    as_tenant(tenant) { staff.update!(invited_at: 1.second.from_now) }

    accept(token:)

    expect_failure(invalid_token)
  end

  it "refuses a token that is not one" do
    accept(token: SecureRandom.urlsafe_base64)

    expect_failure(invalid_token)
  end

  it "refuses a password reset token" do
    accept(token: as_tenant(tenant) { staff.password_reset_token })

    expect_failure(invalid_token)
  end

  it "refuses a token sent with another store's slug" do
    accept(token: invite_token, slug: create(:tenant).slug)

    expect_failure(invalid_token)
  end

  it "refuses an unknown store" do
    accept(token: invite_token, slug: "#{tenant.slug}-missing")

    expect_failure(invalid_token)
  end

  it "refuses a blank password and keeps the token usable" do
    token = invite_token

    accept(token:, password: "")
    expect_failure(invalid_password)

    accept(token:)
    expect(response).to have_http_status(:created)
  end

  it "refuses a password longer than bcrypt accepts" do
    too_long = "a" * (ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED + 1)

    accept(token: invite_token, password: too_long)

    expect_failure(invalid_password)
  end

  it "accepts into a pending store" do
    tenant.update!(status: "pending")

    accept(token: invite_token)

    expect(response).to have_http_status(:created)
  end

  context "when the store is suspended" do
    before { tenant.update!(status: "suspended") }

    it "refuses a valid token and keeps the member pending" do
      accept(token: invite_token)

      expect_failure(RequiresStaffSession::FAILURES.fetch(:tenant_suspended))
      expect(as_tenant(tenant) { staff.reload.status }).to eq("pending")
    end

    it "answers a bad token as invalid, so the status stays hidden" do
      accept(token: SecureRandom.urlsafe_base64)

      expect_failure(invalid_token)
    end
  end
end
