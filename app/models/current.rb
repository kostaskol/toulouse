class Current < ActiveSupport::CurrentAttributes
  attribute :resolution
  attribute :api_key_digest

  def tenant
    resolution&.tenant
  end

  def tenant_id
    resolution&.tenant&.id
  end
end
