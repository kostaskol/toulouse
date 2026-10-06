require "rails_helper"

RSpec.describe Tenancy::Scoped do
  let(:tenant) { create(:tenant) }
  let(:other_tenant) { create(:tenant) }

  describe "reads with a current tenant" do
    it "returns only the current tenant's rows" do
      other_tenant
      as_tenant(tenant)

      expect(Tenant::Setting.pluck(:tenant_id)).to eq([tenant.id])
    end

    it "cannot find another tenant's row by id" do
      other_setting = other_tenant.setting
      as_tenant(tenant)

      expect(Tenant::Setting.find_by(id: other_setting.id)).to be_nil
    end

    it "does not count another tenant's rows" do
      create(:tenant_api_key, tenant: other_tenant)
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

  describe "writes" do
    it "saves a record belonging to the current tenant" do
      as_tenant(tenant)

      expect { Tenant::ApiKey.create!(attributes_for(:tenant_api_key)) }.to change(Tenant::ApiKey, :count).by(1)
    end

    it "rejects a new record assigned to another tenant" do
      as_tenant(tenant)
      key = Tenant::ApiKey.new(attributes_for(:tenant_api_key).merge(tenant_id: other_tenant.id))

      expect { key.save }.to raise_error(Tenancy::CrossTenantWriteError)
    end

    it "rejects a tenant_id change on a persisted record" do
      key = create(:tenant_api_key, tenant: tenant)
      as_tenant(tenant)
      key.tenant_id = other_tenant.id

      expect { key.save }.to raise_error(Tenancy::CrossTenantWriteError)
    end

    it "allows an unrelated update as the record's tenant" do
      key = create(:tenant_api_key, tenant: tenant)

      expect { as_tenant(tenant) { key.update!(attributes_for(:tenant_api_key)) } }.not_to raise_error
    end

    it "raises when saving with no current tenant and no block" do
      key = create(:tenant_api_key, tenant: tenant)
      key.name = attributes_for(:tenant_api_key)[:name]

      expect { key.save }.to raise_error(Tenancy::NoTenantError)
    end

    it "updates only the current tenant's rows through update_all" do
      mine = create(:tenant_domain, tenant: tenant)
      theirs = create(:tenant_domain, tenant: other_tenant)
      as_tenant(tenant)

      Tenant::Domain.update_all(is_primary: true)

      expect(mine.reload.is_primary).to be(true)
      expect(as_tenant(other_tenant) { theirs.reload.is_primary }).to be(false)
    end
  end
end
