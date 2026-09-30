class GrantAppRoleAccess < ActiveRecord::Migration[8.1]
  def up
    # Where the app still connects as the owner, revoking the metadata tables
    # would strip the owner's own access to them.
    return say("App role is the owner, skipping grants") if app_role_is_owner?

    execute Tenancy::AppRole.grants_sql
  end

  def down
    return if app_role_is_owner?

    role = PG::Connection.quote_ident(Tenancy::AppRole.username)

    execute <<~SQL
      ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM #{role};
      REVOKE ALL ON ALL TABLES IN SCHEMA public FROM #{role};
      REVOKE USAGE ON SCHEMA public FROM #{role};
    SQL
  end

  private

  def app_role_is_owner?
    Tenancy::AppRole.username == select_value("SELECT current_user")
  end
end
