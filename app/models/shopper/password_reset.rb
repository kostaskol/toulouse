# Lets a customer who forgot their password set a new one once an emailed code
# proves they control the inbox.
class Shopper::PasswordReset
  Result = Data.define(:session, :failure) do
    def self.success(session) = new(session:, failure: nil)
    def self.failure(reason) = new(session: nil, failure: reason)
  end

  # Mails a code to a shopper, or the tenant admin reset link to a staff-linked
  # one. Every well-formed email answers alike.
  #
  # @param email [String, nil]
  # @return [Symbol, nil] why the email was refused
  def self.request(email:)
    new(email.to_s).request
  end

  # Sets the new password, ends every existing session, and signs the shopper in.
  #
  # @param email [String, nil]
  # @param code [String, nil]
  # @param password [String, nil]
  # @return [Shopper::PasswordReset::Result]
  def self.complete(email:, code:, password:)
    new(email.to_s).complete(code.to_s, password.to_s)
  end

  def initialize(email)
    @email = Shopper.normalize_value_for(:email, email)
  end

  def request
    return :invalid_email unless URI::MailTo::EMAIL_REGEXP.match?(@email)

    shopper = Shopper.find_by(email: @email)
    if shopper.nil?
      log_refusal(:unknown_email)
    elsif shopper.staff
      # A linked shopper's password is the staff one, which only tenant admin resets.
      StaffMailer.password_reset(shopper.staff).deliver_later
    else
      ShopperMailer.password_reset_code(@email).deliver_later
    end
    nil
  end

  def complete(code, password)
    email_code = Shopper::EmailCode.matching(@email, code, purpose: :password_reset)
    return Result.failure(:invalid_code) if email_code.nil?

    shopper = Shopper.find_by(email: @email)
    if shopper.nil? || shopper.staff_id
      email_code.destroy!
      log_refusal(shopper ? :linked_to_staff : :unknown_email)
      return Result.failure(:invalid_code)
    end

    # A blank password leaves the digest as it was rather than failing validation.
    shopper.password = password
    return Result.failure(:invalid_password) if password.empty? || !shopper.valid?

    reset(shopper, email_code)
  end

  private

  def reset(shopper, email_code)
    Shopper.transaction do
      shopper.save!
      # Without the argument, an association's delete_all nulls the foreign key.
      shopper.sessions.delete_all(:delete_all)
      email_code.destroy!
      LoginAttempt.clear(@email)
      Result.success(shopper.sessions.create!)
    end
  end

  # Refusals answer alike, so this log is the only place the reason survives.
  def log_refusal(reason)
    Rails.logger.warn { "Shopper password reset refused: #{reason} tenant=#{Current.tenant.slug}" }
  end
end
