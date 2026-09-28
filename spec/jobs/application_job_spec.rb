require "rails_helper"

RSpec.describe ApplicationJob do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:other_tenant) { create(:tenant) }

  before { TenantRecordingJob.performed_tenant_ids = [] }

  it "performs with the tenant that enqueued it" do
    as_tenant(tenant) { TenantRecordingJob.perform_later }

    perform_enqueued_jobs

    expect(TenantRecordingJob.performed_tenant_ids).to eq([ tenant.id ])
  end

  it "discards a job whose tenant was suspended after enqueue" do
    as_tenant(tenant) { TenantRecordingJob.perform_later }
    Tenancy.across_tenants { tenant.update!(status: :suspended) }

    perform_enqueued_jobs

    expect(TenantRecordingJob.performed_tenant_ids).to be_empty
  end

  it "discards a job whose tenant was deleted after enqueue" do
    as_tenant(tenant) { TenantRecordingJob.perform_later }
    tenant.destroy

    perform_enqueued_jobs

    expect(TenantRecordingJob.performed_tenant_ids).to be_empty
  end

  it "performs with no tenant when enqueued without one" do
    TenantRecordingJob.perform_later

    perform_enqueued_jobs

    expect(TenantRecordingJob.performed_tenant_ids).to eq([ nil ])
  end

  # This exact path, because perform_now alone never deserializes and
  # Base.execute wraps in the executor, which restores Current either way.
  it "performs as its own tenant and restores the caller's resolution" do
    job_data = as_tenant(other_tenant) { TenantRecordingJob.new.serialize }
    as_tenant(tenant)

    ActiveJob::Base.deserialize(job_data).perform_now

    expect(TenantRecordingJob.performed_tenant_ids).to eq([ other_tenant.id ])
    expect(Current.tenant_id).to eq(tenant.id)
  end
end
