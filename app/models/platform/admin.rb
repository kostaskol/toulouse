class Platform::Admin < ApplicationRecord
  MAX_FAILURES = 5
  LOCKOUT = 3.minutes
  WINDOW = 1.hour

  # One TOTP step either side, for clock drift.
  OTP_DRIFT = 30.seconds

  OTP_ISSUER = "Toulouse platform admin".freeze

  has_secure_password
  encrypts :otp_secret

  has_many :sessions, dependent: :delete_all

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :otp_secret, presence: true

  # Creates the admin, or resets an existing one's password and second factor
  # and signs them out everywhere.
  #
  # @param email [String]
  # @param password [String]
  # @return [Platform::Admin]
  def self.provision(email:, password:)
    admin = find_or_initialize_by(email:)

    transaction do
      admin.update!(password:, otp_secret: ROTP::Base32.random, last_otp_at: nil, failed_count: 0,
                    last_failed_at: nil, locked_until: nil)
      admin.sessions.delete_all
    end

    admin
  end

  # @return [String] the otpauth URI an authenticator app scans
  def provisioning_uri
    totp.provisioning_uri(email)
  end

  # Accepts a code once, and never one older than the last accepted.
  #
  # @param code [String, nil]
  # @return [Boolean]
  def verify_otp(code)
    accepted_at = totp.verify(code.to_s, drift_behind: OTP_DRIFT.to_i, drift_ahead: OTP_DRIFT.to_i,
                                         after: last_otp_at&.to_i)
    return false unless accepted_at

    update_columns(last_otp_at: Time.zone.at(accepted_at))
    true
  end

  def locked?
    locked_until&.future? || false
  end

  # Counts a failure, and locks the admin on the one that reaches the limit.
  def record_failure
    with_lock do
      now = Time.current
      count = last_failed_at && last_failed_at >= now - WINDOW ? failed_count + 1 : 1

      if count >= MAX_FAILURES
        update_columns(failed_count: 0, last_failed_at: now, locked_until: now + LOCKOUT)
      else
        update_columns(failed_count: count, last_failed_at: now)
      end
    end
  end

  def clear_failures
    update_columns(failed_count: 0, last_failed_at: nil)
  end

  private

  def totp
    ROTP::TOTP.new(otp_secret, issuer: OTP_ISSUER)
  end
end
