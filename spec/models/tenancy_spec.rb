require "rails_helper"

RSpec.describe Tenancy do
  describe ".with_tenant" do
    let(:tenant) { create(:tenant) }

    it "makes the tenant current inside the block" do
      described_class.with_tenant(tenant) { expect(Current.tenant_id).to eq(tenant.id) }
    end

    it "restores the previous tenant after the block" do
      previous = as_tenant

      described_class.with_tenant(tenant) { nil }

      expect(Current.tenant_id).to eq(previous.id)
    end

    it "restores the previous tenant when the block raises" do
      expect { described_class.with_tenant(tenant) { raise ArgumentError } }.to raise_error(ArgumentError)

      expect(Current.tenant_id).to be_nil
    end

    # A block that suspends across a fiber never reaches its ensure, and Puma
    # hands that thread to the next request.
    it "is cleared at the executor boundary after a suspended block left it set" do
      enumerator = Enumerator.new { |yielder| described_class.with_tenant(tenant) { yielder << 1 } }
      enumerator.next

      Rails.application.executor.wrap do
        expect(Current.tenant_id).to be_nil
      end
    end

    it "returns the block's value" do
      expect(described_class.with_tenant(tenant) { :value }).to eq(:value)
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
