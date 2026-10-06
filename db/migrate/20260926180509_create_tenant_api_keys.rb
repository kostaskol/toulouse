class CreateTenantApiKeys < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :tenant_api_keys do |t|
      t.text :name, null: false
      t.text :token_prefix, null: false
      t.text :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.datetime :revoked_at
    end

    # Resolution looks a key up by digest alone, so it identifies one tenant.
    add_index :tenant_api_keys, :token_digest, unique: true
    add_index :tenant_api_keys, [:tenant_id, :created_at]
  end
end
