class RecordingMailer < ApplicationMailer
  def notice(shopper)
    mail(to: shopper.email, subject: "Notice", body: "")
  end
end
