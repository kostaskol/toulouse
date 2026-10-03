module TenantContext
  # Makes a tenant current for the example, so factories and queries behave as
  # they do in a request.
  #
  # @param tenant [Tenant] created when omitted
  # @return [Tenant]
  def as_tenant(tenant = nil, &block)
    tenant ||= create(:tenant)

    return Tenancy.with_tenant(tenant) { block.call(tenant) } if block

    Current.resolution = Tenancy::Resolution.resolved(tenant)
    tenant
  end
end
