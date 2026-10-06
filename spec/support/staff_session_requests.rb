module StaffSessionRequests
  def staff_cookie(session)
    { "Cookie" => "#{RequiresStaffSession::COOKIE}=#{session.token}" }
  end

  def session_set_cookie
    Array(response.headers["set-cookie"]).flat_map { |header| header.split("\n") }
      .find { |cookie| cookie.start_with?("#{RequiresStaffSession::COOKIE}=") }
  end

  def expect_failure(failure)
    expect(response).to have_http_status(failure.status)
    expect(response.parsed_body["errors"]).to eq([{ "code" => failure.code, "message" => failure.message }])
  end
end

RSpec.configure { |config| config.include StaffSessionRequests, type: :request }
