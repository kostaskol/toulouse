class Shopper < ApplicationRecord
  include Tenancy::Scoped
  include HasPassword

  MINIMUM_PASSWORD_LENGTH = 8

  belongs_to :staff, optional: true
  has_many :sessions

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { scope: :tenant_id }, unless: :platform_admin_id?
  validates :staff_id, uniqueness: true, allow_nil: true
  validate :password_set_unless_linked

  private

  def password_set_unless_linked
    if staff_id || platform_admin_id
      errors.add(:password, :present) if password_digest.present?
    elsif password_digest.blank?
      errors.add(:password, :blank)
    end
  end
end
