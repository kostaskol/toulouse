module V1
  module Admin
    class SessionsController < BaseController
      skip_before_action :require_staff_session!, only: :create
      skip_before_action :reject_writes_while_suspended!, only: [:create, :destroy]

      FAILURES = {
        invalid_credentials: Failure.new(
          status: :unauthorized,
          code: "invalid_credentials",
          message: "The store, email or password is incorrect."
        ),
        too_many_attempts: Failure.new(
          status: :too_many_requests,
          code: "too_many_attempts",
          message: "Too many failed attempts. Try again after the time in the Retry-After header."
        )
      }.freeze

      def create
        credentials = params.permit(:slug, :email, :password)
        result = Staff::Login.call(slug: credentials[:slug], email: credentials[:email],
                                   password: credentials[:password])

        if result.session
          act_as(result.session)
          write_session_cookie(result.session)
          render status: :created, json: session_body(result.session)
        elsif result.failure == :too_many_attempts
          retry_after = (result.locked_until - Time.current).ceil
          render_failure(FAILURES.fetch(:too_many_attempts), headers: { "Retry-After" => retry_after.to_s })
        else
          render_failure(FAILURES.fetch(:invalid_credentials))
        end
      end

      def show
        render json: session_body(staff_session)
      end

      def destroy
        staff_session.destroy!
        clear_session_cookie
        head :no_content
      end

      private

      def session_body(session)
        staff = session.staff
        tenant = session.tenant

        {
          staff: { id: staff.id, email: staff.email, role: staff.role },
          tenant: { name: tenant.name, slug: tenant.slug, status: tenant.status }
        }
      end
    end
  end
end
