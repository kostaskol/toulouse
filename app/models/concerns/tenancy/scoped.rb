module Tenancy
  module Scoped
    extend ActiveSupport::Concern

    included do
      belongs_to :tenant

      # Raising rather than returning no rows, so a path that lost its tenant
      # fails instead of looking like an empty store.
      default_scope { where(tenant_id: Tenancy.current_tenant_id!) }

      before_save :guard_tenant!
    end

    private

    # Raises rather than adding a validation error: tenant_id never comes from
    # client input, so a mismatch is always our bug.
    def guard_tenant!
      if persisted? && tenant_id_changed?
        raise Tenancy::CrossTenantWriteError, "#{self.class.name} cannot move between tenants"
      end

      return if tenant_id == Tenancy.current_tenant_id!

      raise Tenancy::CrossTenantWriteError, "#{self.class.name} does not belong to the current tenant"
    end
  end
end
