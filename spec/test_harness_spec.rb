require "rails_helper"

RSpec.describe "Test harness" do
  it "boots Rails in the test environment" do
    expect(Rails.env).to eq("test")
  end

  it "connects to the test database" do
    expect(ActiveRecord::Base.connection).to be_active
  end

  it "exposes FactoryBot syntax methods" do
    expect(self).to respond_to(:build, :create)
  end

  it "loads shoulda-matchers" do
    expect(defined?(Shoulda::Matchers)).to eq("constant")
  end
end
