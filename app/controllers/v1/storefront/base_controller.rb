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
      # The BFF keeps a guest's cart token in a cookie and sends it back here.
      CART_TOKEN_HEADER = "Cart-Token"
      CART_EXPIRES_HEADER = "Cart-Expires"

      # A notice beside a successful response, in the shape of an error.
      Warning = Data.define(:code, :message)

      CARTS_MERGED = Warning.new(
        code: "carts_merged",
        message: "The guest cart was added to the cart this shopper already had."
      )

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
        body = { token: session.token, **session_body(session), **warnings_json(merge_guest_cart(session)) }
        render status: :created, json: body
      end

      # Skipped under impersonation, where the cart cookie is the admin's own.
      #
      # @param session [Shopper::Session]
      # @return [Warning, nil] when the shopper's cart already held lines
      def merge_guest_cart(session)
        return if session.impersonated?

        CARTS_MERGED if Cart.merge_guest!(request.headers[CART_TOKEN_HEADER], session.shopper)
      end

      # @param warnings [Array<Warning, nil, false>]
      # @return [Hash] a warnings key when any is present
      def warnings_json(*warnings)
        warnings = warnings.select(&:itself)
        warnings.any? ? { warnings: warnings.map(&:to_h) } : {}
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
