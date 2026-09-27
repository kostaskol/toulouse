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
end
