class Current < ActiveSupport::CurrentAttributes
  attribute :resolution
  attribute :api_key_digest
  attribute :staff_session_digest
  attribute :user
  # The platform admin behind a read-only shopper session. An id, since the app
  # role cannot read platform admins.
  attribute :impersonator_id

  def tenant
    resolution&.tenant
  end

  def tenant_id
    resolution&.tenant&.id
  end
end
