module RequiresStaffSession
  extend ActiveSupport::Concern
  include RendersFailures

  COOKIE = "staff_session".freeze
  COOKIE_PATH = "/admin".freeze

  # A plain cross-site form can send these. A JSON body cannot without a CORS
  # preflight, which only the admin origin passes.
  BODY_METHODS = %w[POST PUT PATCH].freeze

  FAILURES = {
    missing_session: Failure.new(
      status: :unauthorized,
      code: "missing_session",
      message: "No staff session was provided. Log in to tenant admin first."
    ),
    invalid_session: Failure.new(
      status: :unauthorized,
      code: "invalid_session",
      message: "The staff session is not recognised. It may have expired or been logged out."
    ),
    tenant_suspended: Failure.new(
      status: :forbidden,
      code: "tenant_suspended",
      message: "The store is suspended. It can be viewed but not changed."
    ),
    unsupported_media_type: Failure.new(
      status: :unsupported_media_type,
      code: "unsupported_media_type",
      message: "Send the request body as application/json."
    )
  }.freeze

  included do
    before_action :require_json_body!
    before_action :require_staff_session!
    before_action :reject_writes_while_suspended!
  end

  private

  attr_reader :staff_session

  def require_json_body!
    return unless BODY_METHODS.include?(request.request_method)
    return if request.media_type == Mime[:json].to_s

    render_failure(FAILURES.fetch(:unsupported_media_type))
  end

  def require_staff_session!
    token = cookies[COOKIE]
    return render_failure(FAILURES.fetch(:missing_session)) if token.blank?

    @staff_session = Staff::Session.authenticate(token)

    if @staff_session.nil?
      clear_session_cookie
      return render_failure(FAILURES.fetch(:invalid_session))
    end

    act_as(@staff_session)
    @staff_session.refresh_expiry
  end

  def reject_writes_while_suspended!
    return if request.get? || request.head?

    render_failure(FAILURES.fetch(:tenant_suspended)) if Current.tenant.suspended?
  end

  def act_as(session)
    Current.resolution = Tenancy::Resolution.resolved(session.tenant)
    Current.user = session.staff
  end

  def write_session_cookie(session)
    cookies[COOKIE] = {
      value: session.token,
      httponly: true,
      same_site: :strict,
      path: COOKIE_PATH,
      # Development and test run over plain HTTP.
      secure: !Rails.env.local?,
      expires: session.absolute_expiry
    }
  end

  def clear_session_cookie
    cookies.delete(COOKIE, path: COOKIE_PATH)
  end
end
