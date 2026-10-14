class Tenant::Domain < ApplicationRecord
  include Tenancy::Scoped

  before_validation { hostname&.downcase! }

  validates :hostname, presence: true

  # @return [String] the storefront's origin on this domain
  def url = "https://#{hostname}"
end
