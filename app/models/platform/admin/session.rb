class Platform::Admin::Session < ApplicationRecord
  # Distinct from every other token type, so a surface can reject a platform
  # token without a query.
  TOKEN_PREFIX = "tpa_".freeze

  IDLE_TIMEOUT = 30.minutes
  ABSOLUTE_TIMEOUT = 8.hours

  # Keeps the idle deadline from turning every request into a write. Short,
  # because a longer throttle eats a large part of a 30 minute idle window.
  REFRESH_THROTTLE = 1.minute

  # Readable only on the instance that generated it. Nothing recovers it later.
  attr_reader :token

  belongs_to :admin

  before_create :assign_token

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  # @param token [String, nil]
  # @return [Platform::Admin::Session, nil] the live session for the token
  def self.authenticate(token)
    # Binary because a cookie is bytes, and invalid bytes under a text encoding
    # raise from String methods.
    token = token&.b
    return unless token&.start_with?(TOKEN_PREFIX)

    session = find_by(token_digest: digest(token))
    session if session&.live?
  end

  def live?
    expires_at.future?
  end

  def absolute_expiry
    created_at + ABSOLUTE_TIMEOUT
  end

  def refresh_expiry
    refreshed = [IDLE_TIMEOUT.from_now, absolute_expiry].min
    update_columns(expires_at: refreshed) if refreshed - expires_at >= REFRESH_THROTTLE
  end

  private

  def assign_token
    @token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    self.token_digest = self.class.digest(@token)
    self.expires_at = IDLE_TIMEOUT.from_now
  end
end
