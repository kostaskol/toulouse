require "rails_helper"

RSpec.describe Tenancy::Resolution do
  it "carries the tenant and no reason when resolved" do
    tenant = build(:tenant)
    resolution = described_class.resolved(tenant)

    expect(resolution).to be_resolved
    expect(resolution.tenant).to eq(tenant)
    expect(resolution.reason).to be_nil
  end

  it "carries the reason and no tenant when it failed" do
    resolution = described_class.failed(:invalid_api_key)

    expect(resolution).not_to be_resolved
    expect(resolution.tenant).to be_nil
    expect(resolution.reason).to eq(:invalid_api_key)
  end
end
