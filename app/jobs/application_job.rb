class ApplicationJob < ActiveJob::Base
  # Set during deserialize, so it is nil for a job sent straight to perform_now.
  attr_reader :tenant_id

  def serialize
    super.merge("tenant_id" => Current.tenant_id)
  end

  def deserialize(job_data)
    super
    @tenant_id = job_data["tenant_id"]
  end

  # Wraps perform_now rather than using around_perform, because arguments are
  # deserialized first and row-level security hides a record argument until its
  # tenant is current.
  def perform_now
    within_tenant { super }
  end

  private

  # The tenant is re-read here because a job can sit in the queue across a
  # suspension or a deletion.
  def within_tenant
    return yield if tenant_id.nil?

    tenant = Tenant.find_by(id: tenant_id)
    return Tenancy.with_tenant(tenant) { yield } if tenant&.active?

    # Logged here rather than with discard_on, which sees only errors raised
    # inside perform_now.
    Rails.logger.warn { "Discarded #{self.class.name}: tenant #{tenant_id} is missing or not active" }
    nil
  end
end
