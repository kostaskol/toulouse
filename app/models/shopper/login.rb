# Checks storefront credentials in the current tenant and opens a session.
class Shopper::Login
  Result = Data.define(:session, :failure, :locked_until) do
    def self.success(session) = new(session:, failure: nil, locked_until: nil)
    def self.failure(reason, locked_until: nil) = new(session: nil, failure: reason, locked_until:)
  end

  # @param email [String, nil]
  # @param password [String, nil]
  # @return [Shopper::Login::Result]
  def self.call(email:, password:)
    new(email.to_s, password.to_s).call
  end

  def initialize(email, password)
    @email = email
    @password = password
  end

  def call
    return refuse(:blank_credentials) if @email.blank? || @password.blank?

    if (locked_until = LoginAttempt.locked_until(@email))
      return refuse(:locked, locked_until:)
    end

    shopper = Shopper.find_by(email: @email)
    reason = password_refusal(shopper)

    if reason.nil?
      LoginAttempt.clear(@email)
      return Result.success(shopper.sessions.create!)
    end

    locked_until = LoginAttempt.record_failure(@email)
    refuse(reason, locked_until:)
  end

  private

  # A staff-linked shopper has no password of its own and answers to the staff
  # one.
  def password_refusal(shopper)
    if shopper.nil?
      # Hashes the password anyway, so an unknown email takes as long as a known one.
      Shopper.new(password: @password)
      return :unknown_email
    end

    return :bad_credentials unless (shopper.staff || shopper).authenticate(@password)

    :pending_staff if shopper.staff&.pending?
  end

  # Every reason but a lock answers alike, so this log is the only place the
  # difference survives.
  def refuse(reason, locked_until: nil)
    Rails.logger.warn { "Shopper login refused: #{reason} tenant=#{Current.tenant.slug}" }
    return Result.failure(:too_many_attempts, locked_until:) if locked_until

    Result.failure(:invalid_credentials)
  end
end
