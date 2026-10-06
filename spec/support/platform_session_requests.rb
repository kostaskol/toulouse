module PlatformSessionRequests
  # The first form's token, which is valid only for that form's action.
  def authenticity_token
    Nokogiri::HTML(response.body).at_css("input[name=authenticity_token]")&.[]("value")
  end

  # The page's token, which is valid for any action.
  def page_authenticity_token
    Nokogiri::HTML(response.body).at_css("meta[name=csrf-token]")&.[]("content")
  end

  def platform_log_in(admin, password:, code: ROTP::TOTP.new(admin.otp_secret).now)
    get new_platform_session_path
    post platform_session_path, params: { email: admin.email, password:, code:, authenticity_token: }
  end

  def platform_set_cookie
    Array(response.headers["set-cookie"]).flat_map { |header| header.split("\n") }
      .find { |cookie| cookie.start_with?("#{Platform::BaseController::COOKIE}=") }
  end
end

RSpec.configure { |config| config.include PlatformSessionRequests, type: :request }
