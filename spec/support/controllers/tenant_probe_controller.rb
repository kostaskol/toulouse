# No tenant-scoped endpoint exists until the versioned controller hierarchy.
class TenantProbeController < ApplicationController
  include Tenancy::RequiresTenant

  def show
    render json: { tenant_id: Current.tenant.id }
  end
end
