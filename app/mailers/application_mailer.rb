class ApplicationMailer < ActionMailer::Base
  class MissingSenderError < StandardError
    def initialize(message = "The tenant has no sender_email in its settings.")
      super
    end
  end

  class MissingPrimaryDomainError < StandardError
    def initialize(message = "The tenant has no primary domain to link its storefront to.")
      super
    end
  end

  self.delivery_job = TenantMailDeliveryJob

  default from: -> { tenant_sender }
  layout "mailer"

  helper_method :storefront_url, :admin_url

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

  # Links to a page on the tenant's storefront.
  #
  # @param path [String]
  # @param token [String, nil]
  # @return [String]
  def storefront_url(path, token: nil)
    domain = Current.tenant.domains.find_by(is_primary: true) || raise(MissingPrimaryDomainError)

    link("https://#{domain.hostname}", path, token)
  end

  # Links to a page in tenant admin.
  #
  # @param path [String]
  # @param token [String, nil]
  # @return [String]
  def admin_url(path, token: nil)
    origin = Rails.configuration.x.admin_origin.presence || raise(KeyError, "ADMIN_ORIGIN is not set")

    link(origin, path, token)
  end

  def link(origin, path, token)
    # Browsers never send the fragment to a server or in Referer, so the token
    # stays out of request logs.
    URI.join(origin, path).tap { |uri| uri.fragment = token }.to_s
  end
end
