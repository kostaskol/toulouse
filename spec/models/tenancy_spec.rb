require "rails_helper"

RSpec.describe Tenancy do
  describe ".across_tenants?" do
    it "is false outside a block" do
      expect(described_class).not_to be_across_tenants
    end

    it "is true inside a block" do
      described_class.across_tenants { expect(described_class).to be_across_tenants }
    end

    it "is false again after the block" do
      described_class.across_tenants { nil }

      expect(described_class).not_to be_across_tenants
    end

    it "stays true in a nested block and after it returns" do
      described_class.across_tenants do
        described_class.across_tenants { nil }

        expect(described_class).to be_across_tenants
      end
    end

    it "is restored when the block raises" do
      expect { described_class.across_tenants { raise ArgumentError } }.to raise_error(ArgumentError)

      expect(described_class).not_to be_across_tenants
    end

    # A block that suspends across a fiber never reaches its ensure, and Puma
    # hands that thread to the next request.
    it "is cleared at the executor boundary after a suspended block left it set" do
      enumerator = Enumerator.new { |yielder| described_class.across_tenants { yielder << 1 } }
      enumerator.next

      Rails.application.executor.wrap do
        expect(described_class).not_to be_across_tenants
      end
    end
  end

  describe ".across_tenants" do
    it "returns the block's value" do
      expect(described_class.across_tenants { :value }).to eq(:value)
    end
  end

  describe ".current_tenant_id!" do
    it "returns the current tenant's id" do
      tenant = create(:tenant)
      Current.resolution = Tenancy::Resolution.resolved(tenant)

      expect(described_class.current_tenant_id!).to eq(tenant.id)
    end

    it "raises when no tenant is set" do
      expect { described_class.current_tenant_id! }.to raise_error(Tenancy::NoTenantError)
    end
  end

  describe "the as_tenant spec helper" do
    it "sets the current tenant for the example" do
      tenant = create(:tenant)

      as_tenant(tenant)

      expect(Current.tenant_id).to eq(tenant.id)
    end

    it "restores the previous resolution after a block" do
      as_tenant(create(:tenant)) { nil }

      expect(Current.tenant_id).to be_nil
    end

    it "creates a tenant when given none" do
      tenant = as_tenant

      expect(Current.tenant_id).to eq(tenant.id)
    end
  end
end
