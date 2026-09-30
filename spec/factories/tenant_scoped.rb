FactoryBot.define do
  # Saves as the record's own tenant, so setup can create another tenant's rows.
  # A spec about a rejected cross-tenant write must not write through a factory.
  trait :tenant_scoped do
    # Created even when building, because a scoped model cannot be instantiated
    # without a tenant id.
    tenant { Current.tenant || association(:tenant, strategy: :create) }

    initialize_with { Tenancy.with_tenant(tenant) { new(attributes) } }
    to_create { |record| Tenancy.with_tenant(record.tenant) { record.save! } }
  end
end
