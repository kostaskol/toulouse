class Staff::Session < ApplicationRecord
  include Tenancy::Scoped

  # Distinct from every other token type, so a surface can reject a staff token
  # without a query.
  TOKEN_PREFIX = "tst_".freeze

  IDLE_TIMEOUT = 4.hours
  ABSOLUTE_TIMEOUT = 48.hours

  # Keeps the idle deadline from turning every request into a write.
  REFRESH_THROTTLE = 5.minutes

  # Readable only on the instance that generated it. Nothing recovers it later.
  attr_reader :token

  belongs_to :staff

  before_create :assign_token

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  # Finds the live session for a token. Runs before any tenant is current, so
  # row-level security admits only the row whose digest is set.
  #
  # @param token [String, nil]
  # @return [Staff::Session, nil]
  def self.authenticate(token)
    # Binary because a cookie is bytes, and invalid bytes under a text encoding
    # raise from String methods.
    token = token&.b
    return unless token&.start_with?(TOKEN_PREFIX)

    token_digest = digest(token)
    session = Current.set(staff_session_digest: token_digest) { unscoped.find_by(token_digest:) }
    session if session&.live?
  end

  def live?
    expires_at.future?
  end

  def absolute_expiry
    created_at + ABSOLUTE_TIMEOUT
  end

  # Must run as the session's tenant, since the lookup policy grants no writes.
  def refresh_expiry
    refreshed = [ IDLE_TIMEOUT.from_now, absolute_expiry ].min
    update_columns(expires_at: refreshed) if refreshed - expires_at >= REFRESH_THROTTLE
  end

  private

  def assign_token
    @token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    self.token_digest = self.class.digest(@token)
    self.expires_at = IDLE_TIMEOUT.from_now
  end
end
