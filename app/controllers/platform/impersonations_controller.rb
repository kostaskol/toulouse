class Platform::ImpersonationsController < Platform::BaseController
  around_action :as_tenant

  # Opens the storefront read-only as the shopper with the given email.
  def create
    @primary_domain = @tenant.primary_domain || raise(ActiveRecord::RecordNotFound)
    shopper = Shopper.find_by(email: params[:email].to_s)

    if shopper.nil?
      @impersonation_error = "No shopper has this email."
      return render "platform/tenants/show", status: :unprocessable_content
    end

    handoff = Shopper::Handoff.issue_impersonation(shopper, Current.user.id)
    response.headers["Cache-Control"] = "no-store"
    redirect_to "#{@primary_domain.url}/#handoff=#{handoff.token}", allow_other_host: true
  end
end
