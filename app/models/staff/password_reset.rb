# Lets a staff member who forgot their password set a new one through an
# emailed link.
class Staff::PasswordReset
  Result = Data.define(:session, :failure) do
    def self.success(session) = new(session:, failure: nil)
    def self.failure(reason) = new(session: nil, failure: reason)
  end

  # Mails a reset link to an active member. Returns nothing, so the caller
  # cannot reveal whether the store or the member exists.
  #
  # @param slug [String, nil]
  # @param email [String, nil]
  def self.request(slug:, email:)
    new(slug.to_s).request(email.to_s)
    nil
  end

  # Sets the new password, ends every session the old one opened, and signs
  # the member in.
  #
  # @param slug [String, nil]
  # @param token [String, nil]
  # @param password [String, nil]
  # @return [Staff::PasswordReset::Result]
  def self.complete(slug:, token:, password:)
    new(slug.to_s).complete(token.to_s, password.to_s)
  end

  def initialize(slug)
    @slug = slug
  end

  def request(email)
    tenant = Tenant.find_by(slug: @slug)
    return log_refusal(:unknown_slug) if tenant.nil?

    Tenancy.with_tenant(tenant) { mail_link(email) }
  end

  def complete(token, password)
    tenant = Tenant.find_by(slug: @slug)
    return refuse(:unknown_slug) if tenant.nil?

    Tenancy.with_tenant(tenant) { reset(token, password) }
  end

  private

  def mail_link(email)
    staff = Staff.find_by(email:)
    # Pending staff set their password by accepting their invite.
    return log_refusal(staff ? :not_active : :unknown_email) unless staff&.active?

    StaffMailer.password_reset(staff).deliver_later
  end

  def reset(token, password)
    # The token embeds part of the password salt, so setting a password spends it.
    staff = Staff.find_by_password_reset_token(token)
    return refuse(staff ? :not_active : :bad_token) unless staff&.active?

    # A blank password leaves the digest as it was rather than failing validation.
    staff.password = password
    return Result.failure(:invalid_password) if password.empty? || !staff.valid?

    Staff.transaction do
      staff.save!
      # Without the argument, an association's delete_all nulls the foreign key.
      staff.sessions.delete_all(:delete_all)
      staff.shopper&.sessions&.delete_all(:delete_all)
      LoginAttempt.clear(staff.email)
      Result.success(staff.sessions.create!)
    end
  end

  def refuse(reason)
    log_refusal(reason)
    Result.failure(:invalid_token)
  end

  # Refusals answer alike, so this log is the only place the reason survives.
  def log_refusal(reason)
    Rails.logger.warn { "Staff password reset refused: #{reason} slug=#{@slug}" }
  end
end
