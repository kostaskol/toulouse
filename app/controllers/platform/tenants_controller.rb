class Platform::TenantsController < Platform::BaseController
  def index
    @tenants = Tenant.order(:name)
  end

  def show
    @tenant = Tenant.find(params[:id])
    @primary_domain = Tenancy.with_tenant(@tenant) { @tenant.primary_domain }
  end
end
