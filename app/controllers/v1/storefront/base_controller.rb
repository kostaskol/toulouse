module V1
  module Storefront
    class BaseController < ApplicationController
      # In this order, because the shopper session is looked up in the tenant
      # the API key resolves.
      include Tenancy::RequiresTenant
      include RequiresShopperSession

      EMAIL_CODE_FAILURES = {
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
          message: "The password is blank, under #{Shopper::MINIMUM_PASSWORD_LENGTH} characters, or too long."
        )
      }.freeze

      private

      def render_new_session(session)
        render status: :created, json: { token: session.token, **session_body(session) }
      end

      def session_body(session)
        shopper = session.shopper

        { shopper: { id: shopper.id, email: shopper.email }, expires_at: session.absolute_expiry }
      end
    end
  end
end
