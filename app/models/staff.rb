class Staff < ApplicationRecord
  include Tenancy::Scoped
  include HasPassword

  # Actions open to every role are declared as such and need no permission here.
  PERMISSIONS = { "owner" => [:manage_staff].freeze, "staff" => [].freeze }.freeze

  INVITE_EXPIRY = 7.days
  # Above the shopper minimum while tenant admin login has no second factor.
  MINIMUM_PASSWORD_LENGTH = 12

  has_many :sessions
  has_one :shopper

  enum :role, { staff: 0, owner: 1 }, validate: true
  enum :status, { pending: 0, active: 1, removed: 2 }, validate: true

  scope :members, -> { where.not(status: :removed) }

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { scope: :tenant_id }
  validate :password_set_when_active

  # Setting the password creates the salt, and a resend moves invited_at, so
  # either one ends the link.
  generates_token_for :invite, expires_in: INVITE_EXPIRY do
    [password_salt&.last(10), invited_at]
  end

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

  # Signs the member out of tenant admin and of the storefront.
  def end_sessions
    # Without the argument, an association's delete_all nulls the foreign key.
    sessions.delete_all(:delete_all)
    shopper&.sessions&.delete_all(:delete_all)
  end

  private

  def password_set_when_active
    errors.add(:password, :blank) if password_digest.blank? && active?
  end
end
