class Staff < ApplicationRecord
  include Tenancy::Scoped

  # Rails' own validations require a password on every row, and pending staff
  # have none until they accept their invite.
  has_secure_password validations: false

  # Actions open to every role are declared as such and need no permission here.
  PERMISSIONS = { "owner" => [:manage_staff, :manage_api_keys].freeze, "staff" => [].freeze }.freeze

  has_many :sessions

  enum :role, { staff: 0, owner: 1 }, validate: true
  enum :status, { pending: 0, active: 1 }, validate: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { scope: :tenant_id }
  validates :password, confirmation: { allow_nil: true }
  validate :password_set_unless_pending
  validate :password_fits_bcrypt

  # @param name [Symbol]
  # @return [Boolean]
  def self.permission?(name)
    PERMISSIONS.each_value.any? { |permissions| permissions.include?(name) }
  end

  # @return [Array<Symbol>]
  def permissions
    PERMISSIONS.fetch(role)
  end

  # @param permission [Symbol]
  # @return [Boolean]
  def can?(permission)
    permissions.include?(permission)
  end

  private

  def password_set_unless_pending
    errors.add(:password, :blank) if password_digest.blank? && !pending?
  end

  def password_fits_bcrypt
    return unless password.present? && password.bytesize > ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

    errors.add(:password, :password_too_long)
  end
end
