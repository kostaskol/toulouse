class Tenant::Setting < ApplicationRecord
  include Tenancy::Scoped

  store_accessor :settings, :sender_email

  validates :sender_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  # `normalizes` silently skips store accessors.
  def sender_email=(email)
    super(email&.strip&.downcase.presence)
  end
end
