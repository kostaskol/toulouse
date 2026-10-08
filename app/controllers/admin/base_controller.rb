module Admin
  class BaseController < ApplicationController
    include ActionController::Cookies
    include RequiresStaffSession
    include AuthorizesStaff

    private

    def session_body(session)
      staff = session.staff
      tenant = session.tenant

      {
        staff: { id: staff.id, email: staff.email, role: staff.role, permissions: staff.permissions },
        tenant: { name: tenant.name, slug: tenant.slug, status: tenant.status }
      }
    end
  end
end
