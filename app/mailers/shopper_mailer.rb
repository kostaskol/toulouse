class ShopperMailer < ApplicationMailer
  # Mails a code that lets the customer finish creating their account.
  #
  # @param email [String]
  def signup_code(email)
    # Made inside the delivery job, so the plain code never sits in the queue.
    @code = Shopper::SignupCode.issue(email)
    @store_name = Current.tenant.name
    @expires_in_minutes = Shopper::SignupCode::EXPIRY.in_minutes.to_i

    mail(to: email, subject: "Κωδικός επιβεβαίωσης για τον λογαριασμό σας")
  end
end
