class Platform::TenantsController < Platform::BaseController
  def index
    @tenants = Tenant.order(:name)
  end
end
