module V1
  module Storefront
    class BaseController < ApplicationController
      # In this order, because the shopper session is looked up in the tenant
      # the API key resolves.
      include Tenancy::RequiresTenant
      include RequiresShopperSession

      # The BFF sends every request, so the shopper's own IP arrives in this
      # header. The API key vouches for the BFF that sets it.
      SHOPPER_IP_HEADER = "X-Shopper-Ip"

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

      # Every surface keys the store by slug, so they share a bucket.
      def account_email_store = Current.tenant.slug

      def account_email_ip
        IPAddr.new(request.headers[SHOPPER_IP_HEADER].to_s)
      rescue IPAddr::Error
        IPAddr.new(request.remote_ip)
      end

      def render_new_session(session)
        render status: :created, json: { token: session.token, **session_body(session) }
      end

      def session_body(session)
        shopper = session.shopper

        {
          shopper: { id: shopper.id, email: shopper.email },
          expires_at: session.absolute_expiry,
          read_only: session.impersonated?
        }
      end
    end
  end
end
