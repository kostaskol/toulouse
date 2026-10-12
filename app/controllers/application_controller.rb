class ApplicationController < ActionController::API
  include RendersFailures

  FAILURES = {
    not_found: Failure.new(status: :not_found, code: "not_found", message: "No record matches this request.")
  }.freeze

  rescue_from(ActiveRecord::RecordNotFound) { render_failure(ApplicationController::FAILURES.fetch(:not_found)) }
  rescue_from(ActiveRecord::RecordInvalid) { |error| render_invalid(error.record) }
end
