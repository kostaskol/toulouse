# Checks tenant admin credentials and opens a session.
class Staff::Login
  Result = Data.define(:session, :failure, :locked_until) do
    def self.success(session) = new(session:, failure: nil, locked_until: nil)
    def self.failure(reason, locked_until: nil) = new(session: nil, failure: reason, locked_until:)
  end

  # @param slug [String, nil]
  # @param email [String, nil]
  # @param password [String, nil]
  # @return [Staff::Login::Result]
  def self.call(slug:, email:, password:)
    new(slug.to_s, email.to_s, password.to_s).call
  end

  def initialize(slug, email, password)
    @slug = slug
    @email = email
    @password = password
  end

  def call
    return refuse(:blank_credentials) if @slug.blank? || @email.blank? || @password.blank?

    tenant = Tenant.find_by(slug: @slug)
    return refuse(:unknown_slug) if tenant.nil?

    Tenancy.with_tenant(tenant) { authenticate }
  end

  private

  def authenticate
    if (locked_until = LoginAttempt.locked_until(@email))
      return refuse(:locked, locked_until:)
    end

    staff = Staff.authenticate_by(email: @email, password: @password)

    # A pending member can hold a password before accepting the invite.
    if staff&.active?
      LoginAttempt.clear(@email)
      return Result.success(staff.sessions.create!)
    end

    locked_until = LoginAttempt.record_failure(@email)
    refuse(staff ? :pending : :bad_credentials, locked_until:)
  end

  # Every reason but a lock answers alike, so this log is the only place the
  # difference survives.
  def refuse(reason, locked_until: nil)
    Rails.logger.warn { "Staff login refused: #{reason} slug=#{@slug}" }
    return Result.failure(:too_many_attempts, locked_until:) if locked_until

    Result.failure(:invalid_credentials)
  end
end
