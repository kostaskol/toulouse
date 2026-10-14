class Shopper::Session < ApplicationRecord
  include Tenancy::Scoped
  include ExpiringSession

  # Distinct from every other token type, so a surface can reject a shopper
  # token without a query.
  TOKEN_PREFIX = "tsh_".freeze

  IDLE_TIMEOUT = 30.days
  ABSOLUTE_TIMEOUT = 90.days
  IMPERSONATION_TIMEOUT = 30.minutes

  belongs_to :shopper

  # Finds the live session for a token in the current tenant. Row-level
  # security hides another tenant's session, so it answers like an unknown one.
  #
  # @param token [String, nil]
  # @return [Shopper::Session, nil]
  def self.authenticate(token)
    token = own_token(token)
    return unless token

    session = find_by(token_digest: digest(token))
    session if session&.live?
  end

  def impersonated? = impersonator_id.present?

  # Both limits match, so use never extends an impersonation.
  def idle_timeout = impersonated? ? IMPERSONATION_TIMEOUT : super
  def absolute_timeout = impersonated? ? IMPERSONATION_TIMEOUT : super
end
