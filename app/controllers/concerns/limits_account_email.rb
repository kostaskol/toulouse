# Caps the requests that mail a code or link to an account email, per store.
# The including controller defines `account_email_store` and `account_email_ip`.
module LimitsAccountEmail
  extend ActiveSupport::Concern

  EMAIL_LIMIT = 3
  EMAIL_WINDOW = 15.minutes
  IP_LIMIT = 20
  IP_WINDOW = 1.hour

  # Every endpoint shares the scope, so one bucket counts all of them.
  SCOPE = "account-email"

  included do
    # The IP limit goes first, so it counts requests the email limit refuses.
    rate_limit to: IP_LIMIT, within: IP_WINDOW, only: :create, scope: SCOPE, name: "ip",
               by: -> { "#{account_email_store}:#{account_email_ip_key}" },
               with: -> { refuse_account_email(:ip) }
    rate_limit to: EMAIL_LIMIT, within: EMAIL_WINDOW, only: :create, scope: SCOPE, name: "email",
               by: -> { "#{account_email_store}:#{params[:email].to_s.strip.downcase}" },
               with: -> { refuse_account_email(:email) }
  end

  private

  # An IPv6 client usually holds a whole /64, so one address per client would not limit it.
  def account_email_ip_key
    # A dual-stack BFF reports IPv4 shoppers as ::ffff:a.b.c.d, which a /64 mask would merge.
    ip = account_email_ip.native
    (ip.ipv6? ? ip.mask(64) : ip).to_s
  end

  # Answers as a normal request does, so the limit reveals nothing about the account.
  def refuse_account_email(bucket)
    Rails.logger.warn { "Account email limited: bucket=#{bucket} store=#{account_email_store}" }
    head :accepted
  end
end
