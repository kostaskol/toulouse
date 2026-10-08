class StaffMailer < ApplicationMailer
  # The tenant admin page that takes the token and a new password.
  PASSWORD_RESET_PATH = "/password-reset".freeze
  # The tenant admin page that takes the token and a first password.
  INVITE_PATH = "/invite".freeze

  self.delivery_job = CredentialMailDeliveryJob

  # Mails a link to set a new password in tenant admin.
  #
  # @param staff [Staff]
  def password_reset(staff)
    @url = store_admin_url(PASSWORD_RESET_PATH, token: staff.password_reset_token)
    @store_name = Current.tenant.name
    @expires_in_minutes = staff.password_reset_token_expires_in.in_minutes.to_i

    mail(to: staff.email, subject: "Επαναφορά κωδικού πρόσβασης")
  end

  # Mails a link to accept an invite and set a first password in tenant admin.
  #
  # @param staff [Staff]
  def invite(staff)
    @url = store_admin_url(INVITE_PATH, token: staff.generate_token_for(:invite))
    @store_name = Current.tenant.name
    @expires_in_days = Staff::INVITE_EXPIRY.in_days.to_i

    mail(to: staff.email, subject: "Πρόσκληση στη διαχείριση του καταστήματος «#{@store_name}»")
  end

  private

  # The page's request has no session, so the slug tells it which store to look in.
  def store_admin_url(path, token:)
    admin_url("#{path}?#{{ slug: Current.tenant.slug }.to_query}", token:)
  end
end
