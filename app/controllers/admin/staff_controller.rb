module Admin
  class StaffController < BaseController
    include Paginates

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
      ),
      last_owner: Failure.new(
        status: :unprocessable_content,
        code: "last_owner",
        message: "The store must keep at least one owner."
      )
    }.freeze

    def index
      members, next_cursor = paginate(Staff.members)
      render json: { staff: members.map { |staff| staff_json(staff) }, meta: { next_cursor: } }
    end

    # Invites a new member, or sends a pending member a new link.
    def create
      result = Staff::Invite.call(email: params.permit(:email)[:email])
      return render_failure(FAILURES.fetch(result.failure)) if result.failure

      render status: result.created ? :created : :ok, json: { staff: staff_json(result.staff) }
    end

    # Cancels a pending member's invite, or removes an active member.
    def destroy
      failure = Staff::Removal.call(Staff.members.find(params[:id]))
      return render_failure(FAILURES.fetch(failure)) if failure

      head :no_content
    end

    private

    def staff_json(staff) = { id: staff.id, email: staff.email, role: staff.role, status: staff.status }
  end
end
