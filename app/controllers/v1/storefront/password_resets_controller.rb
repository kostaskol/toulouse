module V1
  module Storefront
    class PasswordResetsController < BaseController
      # Resetting is how a shopper who cannot sign in gets back in.
      skip_before_action :authenticate_shopper
      include LimitsAccountEmail

      FAILURES = EMAIL_CODE_FAILURES

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
          render_new_session(result.session)
        else
          render_failure(FAILURES.fetch(result.failure))
        end
      end
    end
  end
end
