module V1
  module Storefront
    class BaseController < ApplicationController
      # In this order, because the shopper session is looked up in the tenant
      # the API key resolves.
      include Tenancy::RequiresTenant
      include RequiresShopperSession
    end
  end
end
