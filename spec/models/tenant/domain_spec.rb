require "rails_helper"

RSpec.describe Tenant::Domain, :as_tenant, type: :model do
  it { is_expected.to belong_to(:tenant) }

  it "downcases the hostname before validation" do
    domain = create(:tenant_domain, hostname: "Shop.Example.COM")

    expect(domain.hostname).to eq("shop.example.com")
  end

  it "requires a hostname" do
    expect(build(:tenant_domain, hostname: nil)).not_to be_valid
  end

  describe "database constraints" do
    def insert_domain(tenant:, **attributes)
      as_tenant(tenant) do
        described_class.insert!({
          tenant_id: tenant.id, hostname: "a.example.com", is_primary: false
        }.merge(attributes))
      end
    end

    it "rejects the same hostname for two different tenants" do
      create(:tenant_domain, hostname: "shop.example.com")

      expect { insert_domain(tenant: create(:tenant), hostname: "shop.example.com") }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a hostname that is not lowercase" do
      expect { insert_domain(tenant: create(:tenant), hostname: "Shop.example.com") }
        .to raise_error(ActiveRecord::StatementInvalid, /tenant_domains_hostname_lowercase/)
    end

    it "rejects a second primary domain for the same tenant" do
      tenant = create(:tenant)
      create(:tenant_domain, tenant: tenant, is_primary: true)

      expect { insert_domain(tenant: tenant, hostname: "other.example.com", is_primary: true) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows a primary domain for each of two tenants" do
      create(:tenant_domain, tenant: create(:tenant), is_primary: true)

      expect { create(:tenant_domain, tenant: create(:tenant), is_primary: true) }.not_to raise_error
    end

    it "allows many non-primary domains for one tenant" do
      tenant = create(:tenant)
      create(:tenant_domain, tenant: tenant)

      expect { create(:tenant_domain, tenant: tenant) }.not_to raise_error
    end

    it "requires a tenant" do
      expect { insert_domain(tenant: Tenant.new(id: SecureRandom.uuid_v7)) }
        .to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
