module Tenancy
  module RequiresTenant
    extend ActiveSupport::Concern

    Failure = Data.define(:status, :code, :message)

    FAILURES = {
      missing_api_key: Failure.new(
        status: :unauthorized,
        code: "missing_api_key",
        message: "No API key was provided. Send the tenant API key in the #{Resolve::HEADER} header."
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
      return if Current.resolution&.resolved?

      failure = FAILURES.fetch(Current.resolution&.reason, FAILURES.fetch(:missing_api_key))
      render status: failure.status,
             json: { errors: [ { code: failure.code, message: failure.message } ] }
    end
  end
end
