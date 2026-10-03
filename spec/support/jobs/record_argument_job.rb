class RecordArgumentJob < ApplicationJob
  cattr_accessor :performed_records, default: []

  def perform(record)
    self.class.performed_records << record
  end
end
