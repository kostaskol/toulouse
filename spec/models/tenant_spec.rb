require "rails_helper"

RSpec.describe Tenant, type: :model do
  let(:uuid_v7) { /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}\z/ }

  it { is_expected.to have_many(:domains) }
  it { is_expected.to have_many(:api_keys) }

  it "assigns a UUIDv7 primary key on create" do
    tenant = create(:tenant)

    expect(tenant.id).to match(uuid_v7)
  end

  # UUIDv7 embeds a millisecond timestamp, so ids created within the same
  # millisecond are not ordered relative to each other.
  it "orders ids generated in different milliseconds by creation time" do
    first = create(:tenant).id
    sleep 0.002
    second = create(:tenant).id

    expect(first).to be < second
  end

  it "defaults status to pending" do
    expect(described_class.new.status).to eq("pending")
  end

  it "rejects an unknown status" do
    tenant = build(:tenant)
    tenant.status = "nonsense"

    expect(tenant).not_to be_valid
  end

  it "stores status as an integer" do
    expect(create(:tenant, status: "suspended").status_for_database).to eq(2)
  end

  it "requires a name" do
    expect(build(:tenant, name: nil)).not_to be_valid
  end

  # insert/insert_all skip callbacks, so only a column default covers them.
  it "assigns an id when callbacks are bypassed" do
    described_class.insert!({ name: "Bulk", slug: "bulk", status: "active" })

    expect(described_class.sole.id).to match(uuid_v7)
  end

  describe "database constraints" do
    def insert_tenant(**attributes)
      described_class.insert!({ name: "Test", status: described_class.statuses[:active] }.merge(attributes))
    end

    # An int column has no check constraint, so only Rails guards the enum.
    it "stores an integer outside the enum without complaint" do
      expect { insert_tenant(slug: "bad", status: 99) }.not_to raise_error
    end

    it "rejects a duplicate slug" do
      create(:tenant, slug: "acme")

      expect { insert_tenant(slug: "acme") }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a slug with invalid characters" do
      expect { insert_tenant(slug: "Not A Slug") }
        .to raise_error(ActiveRecord::StatementInvalid, /tenants_slug_format/)
    end

    it "stores timestamps with a time zone" do
      expect(described_class.columns_hash["created_at"].sql_type).to include("with time zone")
    end
  end

  describe "lifecycle with no current tenant" do
    it "creates its setting" do
      expect(create(:tenant).setting).to be_present
    end

    it "destroys its scoped children" do
      tenant = create(:tenant)
      Tenancy.across_tenants { create(:tenant_api_key, tenant: tenant) }
      Tenancy.across_tenants { create(:tenant_domain, tenant: tenant) }

      tenant.destroy

      expect(Tenancy.across_tenants { Tenant::ApiKey.where(tenant_id: tenant.id).count }).to eq(0)
      expect(Tenancy.across_tenants { Tenant::Domain.where(tenant_id: tenant.id).count }).to eq(0)
    end
  end
end
