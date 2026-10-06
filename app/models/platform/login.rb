# Checks platform admin credentials and opens a session.
class Platform::Login
  Result = Data.define(:session, :failure) do
    def self.success(session) = new(session:, failure: nil)
    def self.failure = new(session: nil, failure: :invalid_credentials)
  end

  # @param email [String, nil]
  # @param password [String, nil]
  # @param code [String, nil]
  # @return [Platform::Login::Result]
  def self.call(email:, password:, code:)
    new(email.to_s, password.to_s, code.to_s).call
  end

  def initialize(email, password, code)
    @email = email
    @password = password
    @code = code
  end

  def call
    return refuse(:blank_credentials) if @email.blank? || @password.blank? || @code.blank?

    # Before the lock check, so a lock costs the same bcrypt time.
    admin = Platform::Admin.authenticate_by(email: @email, password: @password)
    account = admin || Platform::Admin.find_by(email: @email)

    return refuse(:locked) if account&.locked?
    return count_failure(:bad_credentials, account) if admin.nil?
    # Only after the password, so nobody without it can spend a code.
    return count_failure(:bad_code, admin) unless admin.verify_otp(@code)

    admin.clear_failures
    Result.success(admin.sessions.create!)
  end

  private

  def count_failure(reason, account)
    account&.record_failure
    refuse(reason)
  end

  # Every reason answers alike, so this log is the only place the difference
  # survives.
  def refuse(reason)
    Rails.logger.warn { "Platform admin login refused: #{reason}" }
    Result.failure
  end
end
