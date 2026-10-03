# No tenant-scoped endpoint exists until the versioned controller hierarchy.
class TenantProbeController < ApplicationController
  include Tenancy::RequiresTenant

  def show
    render json: { tenant_id: Current.tenant.id }
  end

  def domain
    render json: Tenant::Domain.find(params[:id])
  end

  def update_domain
    domain = Tenant::Domain.find(params[:id])
    domain.update!(hostname: params[:hostname])
    render json: domain
  end
end
