ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.include Tenancy::MigrationHelpers
end

ActiveSupport.on_load(:active_record_postgresqladapter) do
  prepend Tenancy::ConnectionSettings
end
