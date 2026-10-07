class Platform::ApiKeysController < Platform::BaseController
  around_action :as_tenant

  def index
    @api_key = Tenant::ApiKey.new
    @api_keys = Tenant::ApiKey.order(created_at: :desc)
  end

  def show
    @api_key = Tenant::ApiKey.find(params[:id])
    response.headers["Cache-Control"] = "no-store"
  end

  def create
    @api_key = Tenant::ApiKey.new(params.expect(api_key: [:name]))

    if @api_key.save
      redirect_to platform_tenant_api_key_path(@tenant, @api_key)
    else
      @api_keys = Tenant::ApiKey.order(created_at: :desc)
      render :index, status: :unprocessable_content
    end
  end

  def revoke
    Tenant::ApiKey.find(params[:id]).revoke!
    redirect_to platform_tenant_api_keys_path(@tenant)
  end

  private

  def as_tenant(&)
    @tenant = Tenant.find(params[:tenant_id])
    Tenancy.with_tenant(@tenant, &)
  end
end
