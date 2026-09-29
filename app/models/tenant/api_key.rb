class Tenant::ApiKey < ApplicationRecord
  include Tenancy::Scoped

  TOKEN_PREFIX = "tou_".freeze

  # Characters of the secret kept in token_prefix so a key is recognisable in a
  # list. Counted after TOKEN_PREFIX, which would otherwise be the whole slice.
  DISPLAY_CHARS = 8

  # Keeps last_used_at from turning every request into a write.
  LAST_USED_THROTTLE = 5.minutes

  # Readable only on the instance that generated it. Nothing recovers it later.
  attr_reader :token

  validates :name, presence: true

  before_create :assign_token

  # SHA-256 rather than bcrypt: the token is 256 bits of randomness, so there is
  # nothing to slow down, and a digest has to be indexable for lookup.
  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def self.authenticate(token)
    return if token.blank?

    key = find_by(token_digest: digest(token))
    key if key&.usable?
  end

  def usable?
    revoked_at.nil? && (expires_at.nil? || expires_at.future?)
  end

  def touch_last_used
    update_columns(last_used_at: Time.current) if last_used_stale?
  end

  def last_used_stale?
    last_used_at.nil? || last_used_at < LAST_USED_THROTTLE.ago
  end

  private

  def assign_token
    @token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    self.token_prefix = @token.first(TOKEN_PREFIX.length + DISPLAY_CHARS)
    self.token_digest = self.class.digest(@token)
  end
end
