class LinkMailer < ApplicationMailer
  def storefront(path, token)
    mail(to: "recipient@example.com", subject: "Link", body: storefront_url(path, token:))
  end

  def admin(path, token)
    mail(to: "recipient@example.com", subject: "Link", body: admin_url(path, token:))
  end
end
