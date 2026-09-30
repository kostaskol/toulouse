module Tenancy
  Resolution = Data.define(:tenant, :api_key, :reason) do
    def self.resolved(tenant, api_key = nil)
      new(tenant: tenant, api_key: api_key, reason: nil)
    end

    def self.failed(reason)
      new(tenant: nil, api_key: nil, reason: reason)
    end

    def resolved?
      reason.nil?
    end

    private_class_method :new
  end
end
