ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.include Tenancy::MigrationHelpers
end
