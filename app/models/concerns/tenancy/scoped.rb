module Tenancy
  module Scoped
    extend ActiveSupport::Concern

    included do
      belongs_to :tenant

      # Raising rather than returning no rows, so a path that lost its tenant
      # fails instead of looking like an empty store.
      default_scope { Tenancy.across_tenants? ? all : where(tenant_id: Tenancy.current_tenant_id!) }
    end
  end
end
