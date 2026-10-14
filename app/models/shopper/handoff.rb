# A one-time token a storefront exchanges for a shopper session, so a platform
# admin reaches a storefront without typing a password on it.
class Shopper::Handoff < ApplicationRecord
  include Tenancy::Scoped
  include ExpiringSession

  # Distinct from every other token type, so a surface can reject another
  # token without a query.
  TOKEN_PREFIX = "thd_".freeze

  # Covers the redirect and the storefront's first page load.
  IDLE_TIMEOUT = 1.minute
  ABSOLUTE_TIMEOUT = IDLE_TIMEOUT

  belongs_to :shopper

  # Issues a handoff to the admin's own shopper in the current tenant, created
  # on first use.
  #
  # @param admin_id [String]
  # @return [Shopper::Handoff]
  def self.issue_for_admin(admin_id)
    create!(shopper: Shopper.create_or_find_by!(platform_admin_id: admin_id))
  end

  # Spends the handoff and opens a session for its shopper. Row-level security
  # hides another tenant's handoff, so it answers like an unknown one.
  #
  # @param token [String, nil]
  # @return [Shopper::Session, nil]
  def self.redeem(token)
    token = own_token(token)
    return unless token

    transaction do
      handoff = lock.find_by(token_digest: digest(token), redeemed_at: nil)
      next unless handoff&.live?

      handoff.update!(redeemed_at: Time.current)
      handoff.shopper.sessions.create!
    end
  end
end
