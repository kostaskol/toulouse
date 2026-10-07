class Shopper < ApplicationRecord
  include Tenancy::Scoped

  # A staff-linked shopper has no password of its own, so Rails' presence check
  # cannot apply to every row.
  has_secure_password validations: false

  belongs_to :staff, optional: true
  has_many :sessions

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { scope: :tenant_id }
  validates :staff_id, uniqueness: true, allow_nil: true
  validates :password, confirmation: { allow_nil: true }
  validate :password_set_unless_linked
  validate :password_fits_bcrypt

  private

  def password_set_unless_linked
    if staff_id
      errors.add(:password, :present) if password_digest.present?
    elsif password_digest.blank?
      errors.add(:password, :blank)
    end
  end

  def password_fits_bcrypt
    return unless password.present? && password.bytesize > ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

    errors.add(:password, :password_too_long)
  end
end
