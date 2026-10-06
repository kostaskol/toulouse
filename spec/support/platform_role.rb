# Transactional tests swap every non-writing pool for the writing one, so a
# platform example would run as the app role. Tagged groups commit instead, run
# as the platform role, and are truncated by the owner afterwards.
module PlatformRole
  extend ActiveSupport::Concern

  included do
    self.use_transactional_tests = false
  end

  def self.truncate_all
    connection = SchemaOwnerRecord.lease_connection
    tables = connection.select_values(<<~SQL)
      SELECT format('%I.%I', schemaname, tablename) FROM pg_tables
      WHERE schemaname IN ('public', 'platform')
        AND tablename NOT IN ('schema_migrations', 'ar_internal_metadata')
    SQL

    connection.execute("TRUNCATE #{tables.join(', ')} CASCADE")
  end
end

RSpec.configure do |config|
  config.include PlatformRole, :platform

  config.around(:each, :platform) do |example|
    ApplicationRecord.connected_to(role: :platform) { example.run }
  ensure
    PlatformRole.truncate_all
  end
end
