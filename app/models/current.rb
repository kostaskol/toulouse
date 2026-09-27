class Current < ActiveSupport::CurrentAttributes
  attribute :resolution

  def tenant
    resolution&.tenant
  end
end
