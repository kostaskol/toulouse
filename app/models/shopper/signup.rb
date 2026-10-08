# Lets a customer create an account in the current tenant once an emailed code
# proves they control the inbox.
class Shopper::Signup
  Result = Data.define(:session, :failure) do
    def self.success(session) = new(session:, failure: nil)
    def self.failure(reason) = new(session: nil, failure: reason)
  end

  # Mails a code to an email that no shopper or staff member holds.
  #
  # @param email [String, nil]
  # @return [Symbol, nil] why no code was sent
  def self.request(email:)
    new(email.to_s).request
  end

  # Creates the shopper and signs them in.
  #
  # @param email [String, nil]
  # @param code [String, nil]
  # @param password [String, nil]
  # @return [Shopper::Signup::Result]
  def self.complete(email:, code:, password:)
    new(email.to_s).complete(code.to_s, password.to_s)
  end

  def initialize(email)
    @email = Shopper.normalize_value_for(:email, email)
  end

  def request
    return :invalid_email unless URI::MailTo::EMAIL_REGEXP.match?(@email)
    return :email_taken if taken?

    ShopperMailer.signup_code(@email).deliver_later
    nil
  end

  def complete(code, password)
    signup_code = Shopper::SignupCode.find_by(email: @email)
    return refuse(:no_code) if signup_code.nil?

    reason = signup_code.refusal(code)
    return refuse(reason) if reason

    if taken?
      signup_code.destroy!
      return Result.failure(:email_taken)
    end

    # A wrong password keeps the code, so the customer can try again.
    shopper = Shopper.new(email: @email, password:)
    return Result.failure(:invalid_password) unless shopper.valid?

    create(shopper, signup_code)
  end

  private

  # Pending staff are included, because accepting the invite creates their
  # linked shopper.
  def taken?
    Shopper.exists?(email: @email) || Staff.exists?(email: @email)
  end

  def create(shopper, signup_code)
    Shopper.transaction do
      shopper.save!
      signup_code.destroy!
      # Login counts failures for unknown emails, so the customer may already be locked.
      LoginAttempt.clear(@email)
      Result.success(shopper.sessions.create!)
    end
  rescue ActiveRecord::RecordNotUnique
    # A parallel signup for the same email committed first.
    Result.failure(:email_taken)
  end

  # Code refusals answer alike, so this log is the only place the reason survives.
  def refuse(reason)
    Rails.logger.warn { "Shopper signup refused: #{reason} tenant=#{Current.tenant.slug}" }
    Result.failure(:invalid_code)
  end
end
