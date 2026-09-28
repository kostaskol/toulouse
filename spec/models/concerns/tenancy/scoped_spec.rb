require "rails_helper"

RSpec.describe Tenancy::Scoped do
  let(:tenant) { create(:tenant) }
  let(:other_tenant) { create(:tenant) }

  describe "reads with a current tenant" do
    it "returns only the current tenant's rows" do
      other_tenant
      as_tenant(tenant)

      expect(Tenant::Setting.pluck(:tenant_id)).to eq([ tenant.id ])
    end

    it "cannot find another tenant's row by id" do
      other_setting = other_tenant.setting
      as_tenant(tenant)

      expect(Tenant::Setting.find_by(id: other_setting.id)).to be_nil
    end

    # Association merge replaces a same column equality rather than anding it,
    # so the foreign key wins over the scope. Only Tenant is an unscoped owner,
    # and TOULIS-27 closes this at the database.
    it "does not filter a traversal from a tenant record" do
      key = Tenancy.across_tenants { create(:tenant_api_key, tenant: other_tenant) }
      as_tenant(tenant)

      expect(other_tenant.api_keys).to eq([ key ])
    end

    it "filters the same rows when they are queried directly" do
      Tenancy.across_tenants { create(:tenant_api_key, tenant: other_tenant) }
      as_tenant(tenant)

      expect(Tenant::ApiKey.count).to eq(0)
    end
  end

  describe "instantiation with a current tenant" do
    it "assigns tenant_id from the scope" do
      as_tenant(tenant)

      expect(Tenant::ApiKey.new.tenant_id).to eq(tenant.id)
    end
  end

  describe "with no current tenant" do
    it "raises when reading" do
      expect { Tenant::Setting.count }.to raise_error(Tenancy::NoTenantError)
    end

    it "raises when instantiating" do
      expect { Tenant::ApiKey.new }.to raise_error(Tenancy::NoTenantError)
    end
  end

  describe "inside across_tenants" do
    it "returns every tenant's rows" do
      tenant
      other_tenant

      ids = Tenancy.across_tenants { Tenant::Setting.pluck(:tenant_id) }

      expect(ids).to contain_exactly(tenant.id, other_tenant.id)
    end

    it "assigns no tenant_id on instantiation" do
      expect(Tenancy.across_tenants { Tenant::ApiKey.new.tenant_id }).to be_nil
    end

    it "ignores a current tenant that is set" do
      as_tenant(tenant)
      other_tenant

      ids = Tenancy.across_tenants { Tenant::Setting.pluck(:tenant_id) }

      expect(ids).to contain_exactly(tenant.id, other_tenant.id)
    end
  end
end
