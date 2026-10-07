module Tenancy
  module RequiresTenant
    extend ActiveSupport::Concern
    include RendersFailures

    HEADER = "X-Api-Key".freeze

    FAILURES = {
      missing_api_key: Failure.new(
        status: :unauthorized,
        code: "missing_api_key",
        message: "No API key was provided. Send the tenant API key in the #{HEADER} header."
      ),
      invalid_api_key: Failure.new(
        status: :unauthorized,
        code: "invalid_api_key",
        message: "The API key is not recognised. It may have been revoked or have expired."
      ),
      inactive: Failure.new(
        status: :not_found,
        code: "tenant_not_found",
        message: "No tenant matches this API key."
      )
    }.freeze

    included do
      before_action :require_tenant!
    end

    private

    def require_tenant!
      Current.resolution = Resolver.call(request.headers[HEADER])

      if Current.resolution.resolved?
        # Only once the tenant is current, because row-level security lets the
        # key's row be written by its own tenant alone.
        Current.resolution.api_key.touch_last_used
        return
      end

      log_resolution_failure(Current.resolution.reason)
      render_failure(FAILURES.fetch(Current.resolution.reason))
    end

    # An inactive tenant is indistinguishable from a missing one on the wire, so
    # this is the only place the reason survives.
    def log_resolution_failure(reason)
      message = "Tenant resolution failed: #{reason} #{request.path}"

      # Scanners and misconfigured clients carry no credential at all. Warning on
      # them would bury the failures where a real credential was rejected.
      if reason == :missing_api_key
        Rails.logger.info { message }
      else
        Rails.logger.warn { message }
      end
    end
  end
end
