module V1
  module Storefront
    class BaseController < ApplicationController
      # In this order, because the shopper session is looked up in the tenant
      # the API key resolves.
      include Tenancy::RequiresTenant
      include RequiresShopperSession

      private

      def session_body(session)
        shopper = session.shopper

        { shopper: { id: shopper.id, email: shopper.email }, expires_at: session.absolute_expiry }
      end
    end
  end
end
