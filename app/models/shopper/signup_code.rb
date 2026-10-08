# An emailed code that proves a customer controls an inbox before their
# account exists.
class Shopper::SignupCode < ApplicationRecord
  include Tenancy::Scoped

  DIGITS = 6
  EXPIRY = 15.minutes
  MAX_ATTEMPTS = 5

  normalizes :email, with: ->(email) { email.strip.downcase }

  scope :expired, -> { where(expires_at: ..Time.current) }

  # Writes a new code for the email, replacing any earlier one.
  #
  # @param email [String]
  # @return [String] the plain code, which nothing can recover later
  def self.issue(email)
    code = SecureRandom.random_number(10**DIGITS).to_s.rjust(DIGITS, "0")

    upsert(
      { tenant_id: Tenancy.current_tenant_id!, email: normalize_value_for(:email, email), code_digest: digest(code),
        expires_at: EXPIRY.from_now, attempts: 0 },
      unique_by: [:tenant_id, :email]
    )
    code
  end

  # Keyed, because a plain hash of a short code is reversed by trying every one.
  #
  # @param code [String]
  # @return [String]
  def self.digest(code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("shopper signup code"), code)
  end

  # Uses up a try, then compares.
  #
  # @param code [String]
  # @return [Symbol, nil] why the code is refused, or nil when it matches
  def refusal(code)
    return :expired unless expires_at.future?
    # One conditional update, so parallel guesses cannot pass the limit.
    return :out_of_attempts if self.class.where(id:, attempts: ...MAX_ATTEMPTS)
                                         .update_all("attempts = attempts + 1").zero?

    :wrong_code unless ActiveSupport::SecurityUtils.secure_compare(code_digest, self.class.digest(code))
  end
end
