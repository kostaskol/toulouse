# Server-rendered, unlike the rest of the app. Runs as the platform database
# role and has no tenant until an action sets one.
class Platform::BaseController < ActionController::Base
  COOKIE = "platform_session".freeze
  COOKIE_PATH = "/platform".freeze

  layout "platform"

  protect_from_forgery with: :exception
  self.forgery_protection_origin_check = true

  around_action :run_as_platform_role
  before_action :require_admin_session

  private

  attr_reader :admin_session

  def run_as_platform_role(&)
    ApplicationRecord.connected_to(role: :platform, &)
  end

  def require_admin_session
    @admin_session = Platform::Admin::Session.authenticate(cookies[COOKIE])

    if @admin_session.nil?
      clear_session_cookie
      return redirect_to(new_platform_session_path)
    end

    Current.user = @admin_session.admin
    @admin_session.refresh_expiry
  end

  def write_session_cookie(session)
    cookies[COOKIE] = {
      value: session.token,
      httponly: true,
      same_site: :strict,
      path: COOKIE_PATH,
      # Development and test run over plain HTTP.
      secure: !Rails.env.local?,
      expires: session.absolute_expiry
    }
  end

  def clear_session_cookie
    cookies.delete(COOKIE, path: COOKIE_PATH)
  end
end
