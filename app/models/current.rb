class Current < ActiveSupport::CurrentAttributes
  attribute :resolution
  attribute :across_tenants

  def tenant
    resolution&.tenant
  end

  def tenant_id
    resolution&.tenant&.id
  end
end
