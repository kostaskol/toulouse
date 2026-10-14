module RequiresShopperSession
  extend ActiveSupport::Concern
  include RendersFailures

  FAILURES = {
    missing_session: Failure.new(
      status: :unauthorized,
      code: "missing_session",
      message: "No shopper session was provided. Send the session token as a Bearer token in the Authorization header."
    ),
    invalid_session: Failure.new(
      status: :unauthorized,
      code: "invalid_session",
      message: "The shopper session is not recognised. It may have expired or been logged out."
    ),
    read_only_session: Failure.new(
      status: :forbidden,
      code: "read_only_session",
      message: "This session views the storefront as the shopper and cannot change anything."
    )
  }.freeze

  included do
    before_action :authenticate_shopper
    before_action :reject_writes_while_impersonating
  end

  private

  attr_reader :shopper_session

  # A refused token answers 401 even where guests are served, so a storefront
  # never shows a shopper as signed in on a session the API has dropped.
  def authenticate_shopper
    authorization = request.authorization
    return if authorization.blank?

    token = authorization.b[/\ABearer +(\S+)\z/, 1]
    @shopper_session = Shopper::Session.authenticate(token)
    return render_failure(FAILURES.fetch(:invalid_session)) if @shopper_session.nil?

    Current.user = @shopper_session.shopper
    Current.impersonator_id = @shopper_session.impersonator_id
    @shopper_session.refresh_expiry
    log_impersonation if @shopper_session.impersonated?
  end

  def reject_writes_while_impersonating
    return if request.get? || request.head? || !shopper_session&.impersonated?

    render_failure(FAILURES.fetch(:read_only_session))
  end

  def log_impersonation
    Rails.logger.tagged("impersonation") do
      Rails.logger.info do
        "admin=#{Current.impersonator_id} shopper=#{Current.user.id} #{request.request_method} #{request.path}"
      end
    end
  end

  def require_shopper_session!
    render_failure(FAILURES.fetch(:missing_session)) if shopper_session.nil?
  end
end
