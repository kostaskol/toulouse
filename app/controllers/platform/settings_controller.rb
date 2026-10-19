class Platform::SettingsController < Platform::BaseController
  around_action :as_tenant

  def update
    @tenant.setting.update!(params.expect(setting: [:weight_required]))
    redirect_to platform_tenant_path(@tenant)
  end
end
