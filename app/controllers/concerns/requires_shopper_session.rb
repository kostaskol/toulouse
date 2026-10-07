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
    )
  }.freeze

  included do
    before_action :authenticate_shopper
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
    @shopper_session.refresh_expiry
  end

  def require_shopper_session!
    render_failure(FAILURES.fetch(:missing_session)) if shopper_session.nil?
  end
end
