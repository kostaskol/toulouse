module Tenancy
  class NoTenantError < StandardError
    def initialize(message = "No tenant is set. If this is wanted, wrap in Tenancy.across_tenants.")
      super
    end
  end

  class CrossTenantWriteError < StandardError; end

  class TenantUnavailableError < StandardError; end

  class << self
    # Runs the block with tenant scoping suspended.
    #
    # @return [Object] the block's value
    def across_tenants
      previous = Current.across_tenants
      Current.across_tenants = true
      yield
    ensure
      Current.across_tenants = previous
    end

    def across_tenants?
      Current.across_tenants == true
    end

    # Reads the tenant every scoped query filters by.
    #
    # @return [String] the current tenant's id
    def current_tenant_id!
      Current.tenant_id || raise(NoTenantError)
    end
  end
end
