# Stands in for tenant admin endpoints until the first resource exists.
class AdminProbeController < V1::Admin::BaseController
  allow_any_staff

  def show
    render json: { tenant_id: Current.tenant.id, staff_id: Current.user.id }
  end

  def update
    head :no_content
  end
end
