class ApplicationMailer < ActionMailer::Base
  class MissingSenderError < StandardError
    def initialize(message = "The tenant has no sender_email in its settings.")
      super
    end
  end

  self.delivery_job = TenantMailDeliveryJob

  default from: -> { tenant_sender }
  layout "mailer"

  private

  # Builds the From header from the current tenant's name and sender address.
  #
  # @return [String]
  def tenant_sender
    tenant = Current.tenant || raise(Tenancy::NoTenantError)
    # No fallback address, so mail never goes out under another name.
    email = tenant.setting.sender_email || raise(MissingSenderError)

    email_address_with_name(email, tenant.name)
  end
end
