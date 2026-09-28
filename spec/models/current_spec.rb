require "rails_helper"

RSpec.describe Current do
  it "reads the tenant through the resolution" do
    tenant = build(:tenant)
    described_class.resolution = Tenancy::Resolution.resolved(tenant)

    expect(described_class.tenant).to eq(tenant)
  end

  it "has no tenant when resolution failed" do
    described_class.resolution = Tenancy::Resolution.failed(:inactive)

    expect(described_class.tenant).to be_nil
  end

  it "has no tenant when nothing resolved" do
    expect(described_class.tenant).to be_nil
  end

  describe "#tenant_id" do
    it "reads through the resolution" do
      tenant = create(:tenant)
      described_class.resolution = Tenancy::Resolution.resolved(tenant)

      expect(described_class.tenant_id).to eq(tenant.id)
    end

    it "is nil with no resolution" do
      expect(described_class.tenant_id).to be_nil
    end

    it "is nil when resolution failed" do
      described_class.resolution = Tenancy::Resolution.failed(:missing_api_key)

      expect(described_class.tenant_id).to be_nil
    end
  end
end
