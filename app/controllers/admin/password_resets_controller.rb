module Admin
  class PasswordResetsController < BaseController
    skip_before_action :require_staff_session!
    # Staff of a suspended store can still sign in, so they can still reset.
    skip_before_action :reject_writes_while_suspended!
    skip_before_action :authorize_staff!

    FAILURES = {
      invalid_token: Failure.new(
        status: :unprocessable_content,
        code: "invalid_token",
        message: "The reset link is invalid or has expired. Request a new one."
      ),
      invalid_password: Failure.new(
        status: :unprocessable_content,
        code: "invalid_password",
        message: "The password is blank or too long."
      )
    }.freeze

    # Answers alike whether or not a member was mailed.
    def create
      details = params.permit(:slug, :email)
      Staff::PasswordReset.request(slug: details[:slug], email: details[:email])

      head :accepted
    end

    def update
      details = params.permit(:slug, :token, :password)
      result = Staff::PasswordReset.complete(slug: details[:slug], token: details[:token],
                                             password: details[:password])

      if result.session
        act_as(result.session)
        write_session_cookie(result.session)
        render status: :created, json: session_body(result.session)
      else
        render_failure(FAILURES.fetch(result.failure))
      end
    end
  end
end
