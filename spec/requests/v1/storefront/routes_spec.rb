require "rails_helper"

RSpec.describe "Storefront routes", type: :request do
  it "take no format suffix" do
    storefront = Rails.application.routes.routes.select do |route|
      route.defaults[:controller]&.start_with?("v1/storefront/")
    end

    expect(storefront).not_to be_empty
    expect(storefront.map { |route| route.path.spec.to_s }).to all(satisfy { |path| !path.include?("format") })
  end
end
