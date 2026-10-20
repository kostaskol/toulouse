class PurgeExpiredCartsJob < ApplicationJob
  # Row-level security hides every tenant's rows from a job with none set.
  def perform
    Tenant.find_each do |tenant|
      Tenancy.with_tenant(tenant) { Cart.expired.delete_all }
    end
  end
end
