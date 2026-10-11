require "rails_helper"

# Committed rather than rolled back, so the platform role connects as itself.
RSpec.describe Tenancy::IsolationCheck, :platform do
  let(:tenant) { create(:tenant) }

  def failures = described_class.failures(ActiveRecord::Base.lease_connection, ApplicationRecord.lease_connection)

  before { create(:staff, tenant:) }

  it "finds nothing with no tenant set" do
    expect(failures).to be_empty
  end

  it "reports tenant rows the app role can see" do
    expect(as_tenant(tenant) { failures }).to include("the app role sees 1 staff rows")
  end
end
