module Tenancy
  class Resolver
    def self.call(token)
      new(token).call
    end

    # Binary because a credential is bytes, and invalid bytes under a text
    # encoding raise from String#blank?.
    def initialize(token)
      @token = token&.dup&.force_encoding(Encoding::BINARY)
    end

    def call
      return Resolution.failed(:missing_api_key) if @token.blank?

      api_key = Tenant::ApiKey.authenticate(@token)
      return Resolution.failed(:invalid_api_key) if api_key.nil?
      return Resolution.failed(:inactive) unless api_key.tenant.active?

      Resolution.resolved(api_key.tenant, api_key)
    end
  end
end
