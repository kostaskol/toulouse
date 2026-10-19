class Tenant::Setting < ApplicationRecord
  include Tenancy::Scoped

  store_accessor :settings, :sender_email, :weight_required

  validates :sender_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  # `normalizes` silently skips store accessors.
  def sender_email=(email)
    super(email&.strip&.downcase.presence)
  end

  # Platform admin sets it from the merchant's answer at onboarding. Feeds need weight only for weight-based
  # shipping rules, which the engine panels hold.
  def weight_required=(value)
    super(ActiveModel::Type::Boolean.new.cast(value) || false)
  end

  def weight_required? = weight_required == true
end
