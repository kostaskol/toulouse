class ApplicationJob < ActiveJob::Base
  # Set during deserialize, so it is nil for a job sent straight to perform_now.
  attr_reader :tenant_id

  discard_on Tenancy::TenantUnavailableError do |job, error|
    Rails.logger.warn { "Discarded #{job.class.name}: #{error.message}" }
  end

  around_perform :within_tenant

  def serialize
    super.merge("tenant_id" => Current.tenant_id)
  end

  def deserialize(job_data)
    super
    @tenant_id = job_data["tenant_id"]
  end

  private

  # The tenant is re-read here because a job can sit in the queue across a
  # suspension or a deletion.
  def within_tenant
    return yield if tenant_id.nil?

    tenant = Tenant.find_by(id: tenant_id)
    raise Tenancy::TenantUnavailableError, "tenant #{tenant_id} is missing or not active" unless tenant&.active?

    Current.set(resolution: Tenancy::Resolution.resolved(tenant)) { yield }
  end
end
