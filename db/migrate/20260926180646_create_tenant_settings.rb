class CreateTenantSettings < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :tenant_settings, one_row_per_tenant: true do |t|
      t.jsonb :settings, null: false, default: {}
    end

    add_check_constraint :tenant_settings, "jsonb_typeof(settings) = 'object'",
                         name: "tenant_settings_is_object"
  end
end
