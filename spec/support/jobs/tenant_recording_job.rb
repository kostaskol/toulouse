class TenantRecordingJob < ApplicationJob
  cattr_accessor :performed_tenant_ids, default: []

  def perform
    self.class.performed_tenant_ids << Current.tenant_id
  end
end
