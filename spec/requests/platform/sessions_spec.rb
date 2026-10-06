require "rails_helper"

RSpec.describe "Platform admin sessions", :platform, type: :request do
  let(:password) { SecureRandom.alphanumeric(16) }
  let(:admin) { create(:platform_admin, password:) }

  def refusal_message
    expect(response).to have_http_status(:unauthorized)
    expect(platform_set_cookie).to be_nil
    Nokogiri::HTML(response.body).at_css("[role=alert]").text
  end

  describe "signing in" do
    it "opens a session and lands on the platform home page" do
      platform_log_in(admin, password:)

      expect(response).to redirect_to(platform_root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(admin.email)
    end

    it "sets a strict, HttpOnly session cookie scoped to platform admin" do
      platform_log_in(admin, password:)

      expect(platform_set_cookie).to include("path=/platform", "httponly", "samesite=strict")
        .and(match(/expires=/i))
    end

    it "refuses a wrong password, a wrong code and an unknown email alike" do
      platform_log_in(admin, password: SecureRandom.alphanumeric(16))
      wrong_password = refusal_message
      platform_log_in(admin, password:, code: ROTP::TOTP.new(admin.otp_secret).at(1.hour.ago))
      wrong_code = refusal_message
      platform_log_in(build(:platform_admin), password:)

      expect(refusal_message).to eq(wrong_password).and eq(wrong_code)
    end

    it "rejects a sign-in without the form's authenticity token" do
      post platform_session_path,
           params: { email: admin.email, password:, code: ROTP::TOTP.new(admin.otp_secret).now }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Platform::Admin::Session.count).to eq(0)
    end
  end

  describe "pages behind the session" do
    it "redirects to the sign-in form without a session" do
      get platform_root_path

      expect(response).to redirect_to(new_platform_session_path)
    end

    it "redirects a staff session token to the sign-in form" do
      cookies[Platform::BaseController::COOKIE] = "#{Staff::Session::TOKEN_PREFIX}#{SecureRandom.hex}"
      get platform_root_path

      expect(response).to redirect_to(new_platform_session_path)
    end

    it "redirects an expired session to the sign-in form" do
      platform_log_in(admin, password:)
      travel Platform::Admin::Session::IDLE_TIMEOUT + 1.second
      get platform_root_path

      expect(response).to redirect_to(new_platform_session_path)
    end
  end

  describe "signing out" do
    it "ends the session and returns to the sign-in form" do
      platform_log_in(admin, password:)
      get platform_root_path
      post platform_logout_path, params: { authenticity_token: }

      expect(response).to redirect_to(new_platform_session_path)
      expect(Platform::Admin::Session.count).to eq(0)
      get platform_root_path
      expect(response).to redirect_to(new_platform_session_path)
    end
  end
end
