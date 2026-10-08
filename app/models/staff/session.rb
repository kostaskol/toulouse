class Staff::Session < ApplicationRecord
  include Tenancy::Scoped
  include ExpiringSession

  # Distinct from every other token type, so a surface can reject a staff token
  # without a query.
  TOKEN_PREFIX = "tst_".freeze

  IDLE_TIMEOUT = 4.hours
  ABSOLUTE_TIMEOUT = 48.hours

  belongs_to :staff

  # Finds the live session for a token. Runs before any tenant is current, so
  # row-level security admits only the row whose digest is set.
  #
  # @param token [String, nil]
  # @return [Staff::Session, nil]
  def self.authenticate(token)
    token = own_token(token)
    return unless token

    token_digest = digest(token)
    session = Current.set(staff_session_digest: token_digest) { unscoped.find_by(token_digest:) }
    session if session&.live?
  end
end
