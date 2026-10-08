# Delivers mail that lets someone back into their account, which a pending or
# suspended store still needs since every status can sign in.
class CredentialMailDeliveryJob < TenantMailDeliveryJob
  self.tenant_statuses = Tenant.statuses.keys.freeze
end
