class ApplicationController < ActionController::API
  include RendersFailures

  FAILURES = {
    not_found: Failure.new(status: :not_found, code: "not_found", message: "No record matches this request.")
  }.freeze

  before_action :set_paper_trail_whodunnit

  rescue_from(ActiveRecord::RecordNotFound) { render_failure(ApplicationController::FAILURES.fetch(:not_found)) }
  rescue_from(ActiveRecord::RecordInvalid) { |error| render_invalid(error.record) }

  private

  # A proc, because this runs before the session check sets the user.
  def user_for_paper_trail = -> { Current.user&.to_global_id&.to_s }
end
