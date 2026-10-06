require "rails_helper"

RSpec.describe Tenancy::ConnectionSettings do
  let(:connection) { ActiveRecord::Base.lease_connection }
  let(:tenant) { build(:tenant, id: SecureRandom.uuid_v7) }
  let(:other_tenant) { build(:tenant, id: SecureRandom.uuid_v7) }

  def setting(name)
    connection.select_value("SELECT current_setting('#{name}', true)")
  end

  it "sets the current tenant before a query" do
    as_tenant(tenant)

    expect(setting("app.tenant_id")).to eq(tenant.id)
  end

  it "clears the tenant once Current is reset" do
    as_tenant(tenant)
    setting("app.tenant_id")
    Current.reset

    expect(setting("app.tenant_id")).to eq("")
  end

  it "sets the api key digest" do
    Current.api_key_digest = Tenant::ApiKey.digest(SecureRandom.hex)

    expect(setting("app.api_key_digest")).to eq(Current.api_key_digest)
  end

  it "sets the staff session digest" do
    Current.staff_session_digest = Staff::Session.digest(SecureRandom.hex)

    expect(setting("app.staff_session_digest")).to eq(Current.staff_session_digest)
  end

  # The query cache keys on SQL alone, and a hit never reaches Postgres.
  it "does not answer from the query cache across a tenant change" do
    connection.cache do
      as_tenant(tenant)
      setting("app.tenant_id")
      as_tenant(other_tenant)

      expect(setting("app.tenant_id")).to eq(other_tenant.id)
    end
  end

  it "syncs again after a rollback undoes a tenant change" do
    as_tenant(tenant)
    setting("app.tenant_id")

    ActiveRecord::Base.transaction(requires_new: true) do
      as_tenant(other_tenant)
      setting("app.tenant_id")
      raise ActiveRecord::Rollback
    end

    expect(setting("app.tenant_id")).to eq(other_tenant.id)
  end

  it "rolls back an aborted transaction after the tenant changed" do
    as_tenant(tenant)

    ActiveRecord::Base.transaction(requires_new: true) do
      expect { connection.select_value("SELECT 1 / 0") }.to raise_error(ActiveRecord::StatementInvalid)
      as_tenant(other_tenant)
      raise ActiveRecord::Rollback
    end

    expect(setting("app.tenant_id")).to eq(other_tenant.id)
  end

  context "when the session is replaced" do
    # Replacing the session would discard the example's own transaction.
    self.use_transactional_tests = false

    it "applies the tenant again after a reconnect" do
      as_tenant(tenant)
      setting("app.tenant_id")
      connection.reconnect!

      expect(setting("app.tenant_id")).to eq(tenant.id)
    end

    it "applies the tenant again after a reset" do
      as_tenant(tenant)
      setting("app.tenant_id")
      connection.reset!

      expect(setting("app.tenant_id")).to eq(tenant.id)
    end
  end
end
