class ShopperMailer < ApplicationMailer
  # Mails a code that lets the customer finish creating their account.
  #
  # @param email [String]
  def signup_code(email)
    # Made inside the delivery job, so the plain code never sits in the queue.
    @code = Shopper::EmailCode.issue(email, purpose: :signup)
    @store_name = Current.tenant.name
    @expires_in_minutes = Shopper::EmailCode::EXPIRY.in_minutes.to_i

    mail(to: email, subject: "Κωδικός επιβεβαίωσης για τον λογαριασμό σας")
  end

  # Mails a code that lets the customer set a new password.
  #
  # @param email [String]
  def password_reset_code(email)
    # Made inside the delivery job, so the plain code never sits in the queue.
    @code = Shopper::EmailCode.issue(email, purpose: :password_reset)
    @store_name = Current.tenant.name
    @expires_in_minutes = Shopper::EmailCode::EXPIRY.in_minutes.to_i

    mail(to: email, subject: "Επαναφορά κωδικού πρόσβασης")
  end
end
