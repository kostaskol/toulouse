module V1
  module Admin
    class BaseController < ApplicationController
      include ActionController::Cookies
      include RequiresStaffSession
    end
  end
end
