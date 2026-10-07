class Tenant::ApiKey < ApplicationRecord
  include Tenancy::Scoped

  TOKEN_PREFIX = "tou_".freeze

  # Characters of the secret kept in token_prefix so a key is recognisable in a
  # list. Counted after TOKEN_PREFIX, which would otherwise be the whole slice.
  DISPLAY_CHARS = 8

  # Keeps last_used_at from turning every request into a write.
  LAST_USED_THROTTLE = 5.minutes

  class TokenChangeError < StandardError; end

  # Kept so platform admin can show it again. Lookup still goes by digest,
  # because non-deterministic ciphertext cannot be queried.
  encrypts :token

  validates :name, presence: true

  before_create :assign_token
  before_update :guard_token!

  # SHA-256 rather than bcrypt: the token is 256 bits of randomness, so there is
  # nothing to slow down, and a digest has to be indexable for lookup.
  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def self.authenticate(token)
    return if token.blank?

    # token_digest is globally unique and is how the tenant is discovered, so
    # there is no tenant yet. Row-level security admits only the row whose digest
    # is current.
    token_digest = digest(token)
    key = Current.set(api_key_digest: token_digest) { unscoped.find_by(token_digest:) }
    key if key&.usable?
  end

  # The stored token, only while it still matches the digest that authenticates.
  #
  # @return [String, nil]
  def verified_token
    token if token.present? && self.class.digest(token) == token_digest
  rescue ActiveRecord::Encryption::Errors::Decryption
    nil
  end

  def usable?
    revoked_at.nil? && (expires_at.nil? || expires_at.future?)
  end

  # Keeps the first revocation time when called again.
  def revoke!
    update!(revoked_at: Time.current) if revoked_at.nil?
  end

  def touch_last_used
    update_columns(last_used_at: Time.current) if last_used_stale?
  end

  def last_used_stale?
    last_used_at.nil? || last_used_at < LAST_USED_THROTTLE.ago
  end

  private

  # Raises rather than adding a validation error: the token never comes from
  # client input, so a change is always our bug.
  def guard_token!
    raise TokenChangeError, "An API key's token cannot change" if token_changed?
  end

  def assign_token
    self.token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    self.token_prefix = token.first(TOKEN_PREFIX.length + DISPLAY_CHARS)
    self.token_digest = self.class.digest(token)
  end
end
