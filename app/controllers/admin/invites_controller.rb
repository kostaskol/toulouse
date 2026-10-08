module Admin
  class InvitesController < BaseController
    skip_before_action :require_staff_session!
    # Acceptance checks the suspension itself, after the token.
    skip_before_action :reject_writes_while_suspended!
    skip_before_action :authorize_staff!

    FAILURES = {
      invalid_token: Failure.new(
        status: :unprocessable_content,
        code: "invalid_token",
        message: "The invite link is invalid or has expired. Ask the store owner for a new one."
      ),
      invalid_password: Failure.new(
        status: :unprocessable_content,
        code: "invalid_password",
        message: "The password is blank or too long."
      ),
      tenant_suspended: RequiresStaffSession::FAILURES.fetch(:tenant_suspended)
    }.freeze

    def update
      details = params.permit(:slug, :token, :password)
      result = Staff::InviteAcceptance.call(slug: details[:slug], token: details[:token],
                                            password: details[:password])

      if result.session
        act_as(result.session)
        write_session_cookie(result.session)
        render status: :created, json: session_body(result.session).merge(shopper_merged: result.shopper_merged)
      else
        render_failure(FAILURES.fetch(result.failure))
      end
    end
  end
end
