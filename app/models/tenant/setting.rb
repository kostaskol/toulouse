class Tenant::Setting < ApplicationRecord
  include Tenancy::Scoped
end
