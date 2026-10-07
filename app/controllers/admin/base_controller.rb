module Admin
  class BaseController < ApplicationController
    include ActionController::Cookies
    include RequiresStaffSession
    include AuthorizesStaff
  end
end
