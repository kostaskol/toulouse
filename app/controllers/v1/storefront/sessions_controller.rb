module V1
  module Storefront
    class SessionsController < BaseController
      # Signing in is how a shopper replaces a session that has expired.
      skip_before_action :authenticate_shopper, only: :create
      before_action :require_shopper_session!, except: :create

      FAILURES = {
        invalid_credentials: Failure.new(
          status: :unauthorized,
          code: "invalid_credentials",
          message: "The email or password is incorrect."
        ),
        too_many_attempts: Failure.new(
          status: :too_many_requests,
          code: "too_many_attempts",
          message: "Too many failed attempts. Try again after the time in the Retry-After header."
        )
      }.freeze

      def create
        credentials = params.permit(:email, :password)
        result = Shopper::Login.call(email: credentials[:email], password: credentials[:password])

        if result.session
          render status: :created, json: { token: result.session.token, **session_body(result.session) }
        elsif result.failure == :too_many_attempts
          retry_after = (result.locked_until - Time.current).ceil
          render_failure(FAILURES.fetch(:too_many_attempts), headers: { "Retry-After" => retry_after.to_s })
        else
          render_failure(FAILURES.fetch(:invalid_credentials))
        end
      end

      def show
        render json: session_body(shopper_session)
      end

      def destroy
        shopper_session.destroy!
        head :no_content
      end

      private

      def session_body(session)
        shopper = session.shopper

        { shopper: { id: shopper.id, email: shopper.email }, expires_at: session.absolute_expiry }
      end
    end
  end
end
