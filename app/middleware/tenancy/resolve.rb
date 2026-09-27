module Tenancy
  class Resolve
    HEADER = "X-Api-Key".freeze
    ENV_KEY = "HTTP_#{HEADER.upcase.tr("-", "_")}".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      Current.resolution = Resolver.call(env[ENV_KEY])
      log_failure(Current.resolution)
      @app.call(env)
    end

    private

    # An inactive tenant is indistinguishable from a missing one on the wire, so
    # this is the only place the reason survives.
    def log_failure(resolution)
      return if resolution.resolved?

      Rails.logger.warn { "Tenant resolution failed: #{resolution.reason}" }
    end
  end
end
