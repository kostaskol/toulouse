class Tenant::Domain < ApplicationRecord
  include Tenancy::Scoped

  before_validation { hostname&.downcase! }

  validates :hostname, presence: true

  # @return [String] the storefront's origin on this domain
  def url = "https://#{hostname}"

  # @return [String] tenant admin's origin on this domain
  def admin_url
    # A www storefront still has its admin on the bare domain.
    "https://admin.#{hostname.delete_prefix('www.')}"
  end
end
