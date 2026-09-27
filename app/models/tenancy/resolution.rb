module Tenancy
  Resolution = Data.define(:tenant, :reason) do
    def self.resolved(tenant)
      new(tenant: tenant, reason: nil)
    end

    def self.failed(reason)
      new(tenant: nil, reason: reason)
    end

    def resolved?
      reason.nil?
    end

    private_class_method :new
  end
end
