# Stands in for owner-only tenant admin endpoints until the first one exists.
class PermissionProbeController < V1::Admin::BaseController
  allow_any_staff only: :show
  requires_permission :manage_staff, only: :update

  def show
    head :no_content
  end

  def update
    head :no_content
  end

  def destroy
    head :no_content
  end
end
