class PurgeExpiredLoginsJob < ApplicationJob
  # Row-level security hides every tenant's rows from a job with none set.
  def perform
    Tenant.find_each do |tenant|
      Tenancy.with_tenant(tenant) do
        LoginAttempt.expired.delete_all
        Staff::Session.expired.delete_all
        Shopper::Session.expired.delete_all
        Shopper::SignupCode.expired.delete_all
      end
    end
  end
end
