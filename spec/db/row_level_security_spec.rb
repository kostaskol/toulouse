require "rails_helper"

RSpec.describe "Row-level security" do
  let(:connection) { ActiveRecord::Base.lease_connection }
  let(:tenant) { create(:tenant) }
  let(:other_tenant) { create(:tenant) }

  # pg_catalog rather than information_schema, which hides tables the role
  # holds no privilege on.
  def tenant_tables
    connection.select_values(<<~SQL)
      SELECT c.relname FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a ON a.attrelid = c.oid
      WHERE n.nspname = 'public' AND c.relkind = 'r'
        AND a.attname = 'tenant_id' AND NOT a.attisdropped
    SQL
  end

  def count_rows(table)
    connection.select_value("SELECT count(*) FROM #{connection.quote_table_name(table)}")
  end

  describe "policies" do
    it "finds the tenant tables" do
      expect(tenant_tables).to include(Tenant::ApiKey.table_name, Tenant::Domain.table_name, Tenant::Setting.table_name)
    end

    it "enables a tenant isolation policy on every table with a tenant_id" do
      protected_tables = connection.select_values(<<~SQL)
        SELECT c.relname FROM pg_class c
        JOIN pg_policies p ON p.tablename = c.relname AND p.schemaname = 'public'
        WHERE c.relrowsecurity AND p.policyname = 'tenant_isolation'
      SQL

      expect(tenant_tables - protected_tables).to be_empty
    end
  end

  describe "the app role" do
    it "is neither superuser nor able to bypass row-level security" do
      role = connection.select_one("SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user")

      expect(role).to eq("rolsuper" => false, "rolbypassrls" => false)
    end

    it "owns no table, so it cannot disable a policy" do
      owned = connection.select_value("SELECT count(*) FROM pg_class WHERE relowner = (SELECT oid FROM pg_roles WHERE rolname = current_user)")

      expect(owned).to eq(0)
    end

    it "is not the role migrations run as" do
      owner = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "owner")

      expect(owner.configuration_hash[:username]).not_to eq(connection.select_value("SELECT current_user"))
    end
  end

  describe "with no tenant set" do
    before do
      create(:tenant_api_key, tenant: tenant)
      create(:tenant_domain, tenant: tenant)
      create(:staff, tenant: tenant)
      create(:staff_session, tenant: tenant)
      create(:shopper_session, tenant: tenant)
      create(:login_attempt, tenant: tenant)
      as_tenant(tenant) { Shopper::SignupCode.issue(build(:shopper).email) }
    end

    it "sees the rows as their tenant" do
      counts = as_tenant(tenant) { tenant_tables.map { |table| count_rows(table) } }

      expect(counts).to all(be_positive)
    end

    # The factories above set and cleared the tenant on this connection, which
    # is what leaves the setting as '' rather than null.
    it "returns zero rows from every tenant table on a connection that held a tenant" do
      expect(tenant_tables.map { |table| count_rows(table) }).to all(eq(0))
    end
  end

  describe "api key lookup by digest" do
    let!(:key) { create(:tenant_api_key, tenant: tenant) }

    before { create(:tenant_api_key, tenant: other_tenant) }

    it "reveals only the key whose digest is set" do
      Current.api_key_digest = key.token_digest

      expect(connection.select_values("SELECT id FROM tenant_api_keys")).to eq([key.id])
    end

    it "grants no writes" do
      Current.api_key_digest = key.token_digest

      expect(connection.exec_update("UPDATE tenant_api_keys SET last_used_at = now()")).to eq(0)
    end
  end

  describe "staff session lookup by digest" do
    let!(:session) { create(:staff_session, tenant: tenant) }

    before { create(:staff_session, tenant: other_tenant) }

    it "reveals only the session whose digest is set" do
      Current.staff_session_digest = session.token_digest

      expect(connection.select_values("SELECT id FROM staff_sessions")).to eq([session.id])
    end

    it "grants no writes" do
      Current.staff_session_digest = session.token_digest

      expect(connection.exec_update("UPDATE staff_sessions SET expires_at = now()")).to eq(0)
    end

    it "reveals nothing with no digest set" do
      expect(connection.select_values("SELECT id FROM staff_sessions")).to be_empty
    end
  end

  # Each of these reached another tenant's row with only the app layer in place.
  describe "paths that skip the default scope" do
    let!(:theirs) { create(:tenant_api_key, tenant: other_tenant) }

    before { as_tenant(tenant) }

    it "filters a traversal from another tenant's record" do
      expect(other_tenant.api_keys.to_a).to be_empty
    end

    it "does not locate another tenant's row by GlobalID" do
      expect { GlobalID::Locator.locate(theirs.to_global_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not reload another tenant's row" do
      expect { theirs.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "rejects an upsert that lands on another tenant's row" do
      attributes = theirs.attributes.slice("id", "name", "token", "token_prefix", "token_digest")

      expect { Tenant::ApiKey.upsert(attributes, unique_by: :id) }.to raise_error(ActiveRecord::StatementInvalid, /row-level security/)
    end

    it "rejects moving a row to another tenant through update_all" do
      mine = create(:tenant_api_key)

      expect { Tenant::ApiKey.where(id: mine.id).update_all(tenant_id: other_tenant.id) }
        .to raise_error(ActiveRecord::StatementInvalid, /row-level security/)
    end

    it "leaves another tenant's row unchanged by update_column" do
      original = theirs.name

      theirs.update_column(:name, attributes_for(:tenant_api_key)[:name])

      expect(as_tenant(other_tenant) { theirs.reload.name }).to eq(original)
    end
  end
end
