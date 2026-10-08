class StaffMailer < ApplicationMailer
  # The tenant admin page that takes the token and a new password.
  PASSWORD_RESET_PATH = "/password-reset".freeze

  self.delivery_job = CredentialMailDeliveryJob

  # Mails a link to set a new password in tenant admin.
  #
  # @param staff [Staff]
  def password_reset(staff)
    # The completion request has no session, so the slug tells it which store to look in.
    path = "#{PASSWORD_RESET_PATH}?#{{ slug: Current.tenant.slug }.to_query}"
    @url = admin_url(path, token: staff.password_reset_token)
    @store_name = Current.tenant.name
    @expires_in_minutes = staff.password_reset_token_expires_in.in_minutes.to_i

    mail(to: staff.email, subject: "Επαναφορά κωδικού πρόσβασης")
  end
end
