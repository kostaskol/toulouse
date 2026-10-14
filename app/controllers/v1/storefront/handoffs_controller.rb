module V1
  module Storefront
    class HandoffsController < BaseController
      skip_before_action :authenticate_shopper

      FAILURES = {
        invalid_handoff: Failure.new(
          status: :unauthorized,
          code: "invalid_handoff",
          message: "The handoff token is unknown, already used or expired."
        )
      }.freeze

      def create
        session = Shopper::Handoff.redeem(params.permit(:token)[:token])
        return render_failure(FAILURES.fetch(:invalid_handoff)) if session.nil?

        render_new_session(session)
      end
    end
  end
end
