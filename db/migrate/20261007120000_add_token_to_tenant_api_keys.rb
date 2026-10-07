class AddTokenToTenantApiKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :tenant_api_keys, :token, :text, null: false

    # The digest decides which key a request carries, so it never changes. The
    # encrypted token is left out because rotating encryption keys rewrites it.
    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE FUNCTION tenant_api_keys_reject_token_change() RETURNS trigger
            LANGUAGE plpgsql AS $$
          BEGIN
            RAISE EXCEPTION 'tenant_api_keys.token_digest and token_prefix cannot change';
          END;
          $$;

          CREATE TRIGGER freeze_token_digest
            BEFORE UPDATE OF token_digest, token_prefix ON tenant_api_keys
            FOR EACH ROW
            WHEN (OLD.token_digest IS DISTINCT FROM NEW.token_digest
              OR OLD.token_prefix IS DISTINCT FROM NEW.token_prefix)
            EXECUTE FUNCTION tenant_api_keys_reject_token_change();
        SQL
      end

      direction.down do
        execute <<~SQL
          DROP TRIGGER freeze_token_digest ON tenant_api_keys;
          DROP FUNCTION tenant_api_keys_reject_token_change();
        SQL
      end
    end
  end
end
