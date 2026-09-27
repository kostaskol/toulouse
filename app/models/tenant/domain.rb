class Tenant::Domain < ApplicationRecord
  include Tenancy::Scoped

  before_validation { hostname&.downcase! }

  validates :hostname, presence: true
end
