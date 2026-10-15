class ApplicationMailer < ActionMailer::Base
  class MissingSenderError < StandardError
    def initialize(message = "The tenant has no sender_email in its settings.")
      super
    end
  end

  class MissingPrimaryDomainError < StandardError
    def initialize(message = "The tenant has no primary domain to build its links from.")
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
    link(primary_domain.url, path, token)
  end

  # Links to a page in tenant admin.
  #
  # @param path [String]
  # @param token [String, nil]
  # @return [String]
  def admin_url(path, token: nil)
    # Development serves tenant admin on localhost, where no primary domain points.
    origin = Rails.configuration.x.admin_origin.presence || primary_domain.admin_url

    link(origin, path, token)
  end

  def primary_domain = Current.tenant.primary_domain || raise(MissingPrimaryDomainError)

  def link(origin, path, token)
    # Browsers never send the fragment to a server or in Referer, so the token
    # stays out of request logs.
    URI.join(origin, path).tap { |uri| uri.fragment = token }.to_s
  end
end
