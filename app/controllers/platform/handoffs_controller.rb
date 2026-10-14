class Platform::HandoffsController < Platform::BaseController
  around_action :as_tenant

  def create
    domain = @tenant.primary_domain || raise(ActiveRecord::RecordNotFound)
    handoff = Shopper::Handoff.issue_for_admin(Current.user.id)
    response.headers["Cache-Control"] = "no-store"
    # A fragment never reaches a server log or a Referer header.
    redirect_to "#{domain.url}/#handoff=#{handoff.token}", allow_other_host: true
  end
end
