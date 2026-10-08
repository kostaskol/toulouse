class TenantMailDeliveryJob < ActionMailer::MailDeliveryJob
  include Tenancy::Job
end
