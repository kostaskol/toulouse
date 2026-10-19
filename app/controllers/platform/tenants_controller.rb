class Platform::TenantsController < Platform::BaseController
  def index
    @tenants = Tenant.order(:name)
  end

  def show
    @tenant = Tenant.find(params[:id])
    Tenancy.with_tenant(@tenant) do
      @primary_domain = @tenant.primary_domain
      @setting = @tenant.setting
    end
  end
end
