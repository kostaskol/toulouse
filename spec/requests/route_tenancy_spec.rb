require "rails_helper"

RSpec.describe "Tenant resolution on every route", type: :request do
  def self.tenantless = [ "rails/health#show" ]
  def self.routes = Rails.application.routes.routes.reject(&:internal)
  def self.endpoint(route) = "#{route.defaults[:controller]}##{route.defaults[:action]}"

  it "allows only routes that exist to skip the tenant" do
    endpoints = self.class.routes.map { |route| self.class.endpoint(route) }

    expect(self.class.tenantless - endpoints).to be_empty
  end

  routes.reject { |route| tenantless.include?(endpoint(route)) }.each do |route|
    it "rejects #{route.verb} #{route.path.spec} without an api key" do
      # Each segment is filled with its own name, because the request must be
      # turned away before any parameter is read.
      path = route.format(route.required_parts.index_with(&:to_s))

      process route.verb.downcase.to_sym, path

      failure = Tenancy::RequiresTenant::FAILURES.fetch(:missing_api_key)
      expect(response).to have_http_status(failure.status)
      expect(response.parsed_body["errors"]).to eq([ { "code" => failure.code, "message" => failure.message } ])
    end
  end
end
