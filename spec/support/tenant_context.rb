module TenantContext
  # Makes a tenant current for the example, so factories and queries behave as
  # they do in a request.
  #
  # @param tenant [Tenant] created when omitted
  # @return [Tenant]
  def as_tenant(tenant = nil, &block)
    tenant ||= create(:tenant)
    resolution = Tenancy::Resolution.resolved(tenant)

    return Current.set(resolution: resolution) { block.call(tenant) } if block

    Current.resolution = resolution
    tenant
  end
end
