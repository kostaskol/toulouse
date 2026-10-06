class Current < ActiveSupport::CurrentAttributes
  attribute :resolution
  attribute :api_key_digest
  attribute :staff_session_digest
  attribute :user

  def tenant
    resolution&.tenant
  end

  def tenant_id
    resolution&.tenant&.id
  end
end
