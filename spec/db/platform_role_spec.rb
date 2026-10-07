require "rails_helper"

RSpec.describe "Platform database role" do
  def platform_tables(connection)
    connection.select_values(<<~SQL)
      SELECT format('%I.%I', schemaname, tablename) FROM pg_tables WHERE schemaname = 'platform'
    SQL
  end

  describe "the app role" do
    let(:connection) { ActiveRecord::Base.lease_connection }

    it "has no access to the platform schema" do
      usage = connection.select_value("SELECT has_schema_privilege(current_user, 'platform', 'USAGE')")

      expect(usage).to be(false)
    end

    it "is refused when it reads a platform table" do
      expect { connection.select_value("SELECT count(*) FROM #{Platform::Admin.quoted_table_name}") }
        .to raise_error(ActiveRecord::StatementInvalid, /permission denied/)
    end
  end

  describe "the platform role", :platform do
    # Platform controllers switch ApplicationRecord, which every model inherits.
    let(:connection) { ApplicationRecord.lease_connection }

    it "is what platform code connects as" do
      expect(connection.select_value("SELECT current_user")).to eq(Platform::DatabaseRole.username)
    end

    it "is neither superuser nor able to bypass row-level security" do
      role = connection.select_one("SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user")

      expect(role).to eq("rolsuper" => false, "rolbypassrls" => false)
    end

    it "owns nothing, so it cannot disable a policy" do
      owned = connection.select_value(
        "SELECT count(*) FROM pg_class WHERE relowner = (SELECT oid FROM pg_roles WHERE rolname = current_user)"
      )

      expect(owned).to eq(0)
    end

    it "finds the platform tables" do
      expect(platform_tables(connection)).to include(Platform::Admin.table_name, Platform::Admin::Session.table_name)
    end

    it "reads and writes every platform table" do
      privileged = platform_tables(connection).map do |table|
        connection.select_value(
          "SELECT has_table_privilege(current_user, #{connection.quote(table)}, 'SELECT, INSERT, UPDATE, DELETE')"
        )
      end

      expect(privileged).to all(be(true))
    end

    it "sees no tenant rows with no tenant set" do
      create(:staff, tenant: create(:tenant))

      expect(connection.select_value("SELECT count(*) FROM staff")).to eq(0)
    end

    it "sees a tenant's rows as that tenant" do
      tenant = create(:tenant)
      create(:staff, tenant:)

      expect(as_tenant(tenant) { connection.select_value("SELECT count(*) FROM staff") }).to eq(1)
    end
  end
end
