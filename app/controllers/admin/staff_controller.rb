module Admin
  class StaffController < BaseController
    requires_permission :manage_staff

    FAILURES = {
      email_taken: Failure.new(
        status: :unprocessable_content,
        code: "email_taken",
        message: "An active member of the store already has this email."
      ),
      invalid_email: Failure.new(
        status: :unprocessable_content,
        code: "invalid_email",
        message: "The email is blank or malformed."
      )
    }.freeze

    # Invites a new member, or sends a pending member a new link.
    def create
      result = Staff::Invite.call(email: params.permit(:email)[:email])
      return render_failure(FAILURES.fetch(result.failure)) if result.failure

      staff = result.staff
      render status: result.created ? :created : :ok,
             json: { staff: { id: staff.id, email: staff.email, role: staff.role, status: staff.status } }
    end
  end
end
