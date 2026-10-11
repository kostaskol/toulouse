module V1
  module Storefront
    class PasswordResetsController < BaseController
      # Resetting is how a shopper who cannot sign in gets back in.
      skip_before_action :authenticate_shopper

      FAILURES = {
        invalid_email: Failure.new(
          status: :unprocessable_content,
          code: "invalid_email",
          message: "The email is blank or malformed."
        ),
        invalid_code: Failure.new(
          status: :unprocessable_content,
          code: "invalid_code",
          message: "The code is wrong or has expired. Request a new one."
        ),
        invalid_password: Failure.new(
          status: :unprocessable_content,
          code: "invalid_password",
          message: "The password is blank or too long."
        )
      }.freeze

      # Answers alike whether or not a shopper was mailed.
      def create
        failure = Shopper::PasswordReset.request(email: params.permit(:email)[:email])
        return render_failure(FAILURES.fetch(failure)) if failure

        head :accepted
      end

      def update
        details = params.permit(:email, :code, :password)
        result = Shopper::PasswordReset.complete(email: details[:email], code: details[:code],
                                                 password: details[:password])

        if result.session
          render status: :created, json: { token: result.session.token, **session_body(result.session) }
        else
          render_failure(FAILURES.fetch(result.failure))
        end
      end
    end
  end
end
