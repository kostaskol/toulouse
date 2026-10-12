module V1
  module Storefront
    class SignupsController < BaseController
      # Signing up is open to anyone, whatever session the BFF still holds.
      skip_before_action :authenticate_shopper
      include LimitsAccountEmail

      FAILURES = EMAIL_CODE_FAILURES.merge(
        email_taken: Failure.new(
          status: :unprocessable_content,
          code: "email_taken",
          message: "An account with this email already exists. Log in instead."
        )
      ).freeze

      def create
        failure = Shopper::Signup.request(email: params.permit(:email)[:email])
        return render_failure(FAILURES.fetch(failure)) if failure

        head :accepted
      end

      def update
        details = params.permit(:email, :code, :password)
        result = Shopper::Signup.complete(email: details[:email], code: details[:code], password: details[:password])

        if result.session
          render_new_session(result.session)
        else
          render_failure(FAILURES.fetch(result.failure))
        end
      end
    end
  end
end
