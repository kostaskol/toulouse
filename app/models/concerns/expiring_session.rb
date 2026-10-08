# A session row found by the digest of an opaque, prefixed token, which expires
# when idle and at an absolute cap. Including models define TOKEN_PREFIX,
# IDLE_TIMEOUT and ABSOLUTE_TIMEOUT.
module ExpiringSession
  extend ActiveSupport::Concern

  # Keeps the idle deadline from turning every request into a write.
  REFRESH_THROTTLE = 5.minutes

  included do
    # Readable only on the instance that generated it. Nothing recovers it later.
    attr_reader :token

    scope :expired, -> { where(expires_at: ..Time.current) }

    before_create :assign_token
  end

  class_methods do
    def digest(token)
      OpenSSL::Digest::SHA256.hexdigest(token)
    end

    # Rejects another surface's token without a query.
    #
    # @param token [String, nil]
    # @return [String, nil] the token as bytes, when it carries this model's prefix
    def own_token(token)
      # Binary because a credential is bytes, and invalid bytes under a text
      # encoding raise from String methods.
      token = token&.b
      token if token&.start_with?(self::TOKEN_PREFIX)
    end
  end

  def live?
    expires_at.future?
  end

  def absolute_expiry
    created_at + self.class::ABSOLUTE_TIMEOUT
  end

  # Must run as the session's tenant, since row-level security grants no other
  # writes.
  def refresh_expiry
    refreshed = [self.class::IDLE_TIMEOUT.from_now, absolute_expiry].min
    update_columns(expires_at: refreshed) if refreshed - expires_at >= REFRESH_THROTTLE
  end

  private

  def assign_token
    @token = "#{self.class::TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    self.token_digest = self.class.digest(@token)
    self.expires_at = self.class::IDLE_TIMEOUT.from_now
  end
end
