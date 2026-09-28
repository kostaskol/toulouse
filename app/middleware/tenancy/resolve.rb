module Tenancy
  class Resolve
    HEADER = "X-Api-Key".freeze
    ENV_KEY = "HTTP_#{HEADER.upcase.tr("-", "_")}".freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      Current.resolution = Resolver.call(env[ENV_KEY])
      log_failure(Current.resolution, env)
      @app.call(env)
    end

    private

    # An inactive tenant is indistinguishable from a missing one on the wire, so
    # this is the only place the reason survives.
    def log_failure(resolution, env)
      return if resolution.resolved?

      message = "Tenant resolution failed: #{resolution.reason} #{env["PATH_INFO"]}"

      # Health checks and scanners carry no credential at all. Warning on them
      # would bury the failures where a real credential was rejected.
      if resolution.reason == :missing_api_key
        Rails.logger.info { message }
      else
        Rails.logger.warn { message }
      end
    end
  end
end
