class Tenant < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\z/

  enum :status, { pending: 0, active: 1, suspended: 2 }, validate: true

  has_many :domains, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_one :setting, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, format: { with: SLUG_FORMAT }

  after_create { Tenancy.with_tenant(self) { create_setting! } }

  # Deprovisioning has no current tenant, and dependent: :destroy loads scoped
  # children. Overridden rather than around_destroy, which would run inside the
  # association callbacks registered above it.
  def destroy
    Tenancy.with_tenant(self) { super }
  end
end
