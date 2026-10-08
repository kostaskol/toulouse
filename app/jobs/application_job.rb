class ApplicationJob < ActiveJob::Base
  include Tenancy::Job
end
