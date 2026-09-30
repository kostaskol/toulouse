module Tenancy
  class NoTenantError < StandardError
    def initialize(message = "No tenant is set. Resolve one for the request, or wrap the call in Tenancy.with_tenant.")
      super
    end
  end

  class CrossTenantWriteError < StandardError; end

  class << self
    # Runs the block as the given tenant, for work that starts with none, such
    # as provisioning.
    #
    # @param tenant [Tenant]
    # @return [Object] the block's value
    def with_tenant(tenant, &)
      Current.set(resolution: Resolution.resolved(tenant), &)
    end

    # Reads the tenant every scoped query filters by.
    #
    # @return [String] the current tenant's id
    def current_tenant_id!
      Current.tenant_id || raise(NoTenantError)
    end
  end
end
