# Failed logins per submitted email, whether or not an account has it, so a
# lock reveals nothing about which emails exist.
class LoginAttempt < ApplicationRecord
  include Tenancy::Scoped

  MAX_FAILURES = 5
  LOCKOUT = 3.minutes
  WINDOW = 1.hour

  normalizes :email, with: ->(email) { email.strip.downcase }

  scope :expired, -> {
    where(last_failed_at: ...WINDOW.ago).where("locked_until IS NULL OR locked_until < ?", Time.current)
  }

  # @param email [String]
  # @return [ActiveSupport::TimeWithZone, nil] the end of an active lock
  def self.locked_until(email)
    find_by(email:)&.locked_until&.then { |time| time if time.future? }
  end

  # Counts a failure, and locks the email on the one that reaches the limit.
  #
  # @param email [String]
  # @return [ActiveSupport::TimeWithZone, nil] the end of the lock this failure started
  def self.record_failure(email)
    now = Time.current
    count = sanitize_sql_array([<<~SQL.squish, now - WINDOW])
      CASE WHEN login_attempts.last_failed_at < ? THEN 1 ELSE login_attempts.failed_count + 1 END
    SQL
    reached = "#{count} >= #{MAX_FAILURES}"

    # One statement, so concurrent failures cannot both read the same count.
    result = upsert(
      { tenant_id: Tenancy.current_tenant_id!, email: normalize_value_for(:email, email), failed_count: 1,
        last_failed_at: now },
      unique_by: [:tenant_id, :email],
      on_duplicate: Arel.sql(sanitize_sql_array([<<~SQL.squish, now + LOCKOUT, now, now])),
        failed_count = CASE WHEN #{reached} THEN 0 ELSE #{count} END,
        locked_until = CASE WHEN #{reached} THEN ? ELSE login_attempts.locked_until END,
        last_failed_at = ?,
        updated_at = ?
      SQL
      returning: [:locked_until]
    )

    locked_until = type_for_attribute(:locked_until).deserialize(result.rows.first.first)
    locked_until if locked_until&.>=(now)
  end

  def self.clear(email)
    where(email:).delete_all
  end
end
