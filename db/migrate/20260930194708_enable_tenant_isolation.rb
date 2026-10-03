class EnableTenantIsolation < ActiveRecord::Migration[8.1]
  def change
    enable_tenant_isolation :tenant_domains
    enable_tenant_isolation :tenant_settings
    enable_tenant_isolation :tenant_api_keys

    # Resolution reads a key before its tenant is known. Matching one digest
    # reveals a key only to a caller holding its token, and grants no writes.
    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE POLICY api_key_lookup ON tenant_api_keys FOR SELECT
            USING (token_digest = NULLIF(current_setting('app.api_key_digest', true), ''));
        SQL
      end

      direction.down { execute "DROP POLICY api_key_lookup ON tenant_api_keys;" }
    end
  end
end
