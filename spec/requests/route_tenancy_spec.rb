require "rails_helper"

RSpec.describe "Tenant resolution on every route", type: :request do
  def self.tenantless = ["rails/health#show"]
  # Sign-in endpoints, which take credentials rather than a session.
  def self.sessionless = ["admin/sessions#create", "platform/sessions#new", "platform/sessions#create"]
  def self.routes = Rails.application.routes.routes.reject(&:internal)
  def self.endpoint(route) = "#{route.defaults[:controller]}##{route.defaults[:action]}"
  def self.tenant_admin?(route) = route.defaults[:controller].start_with?("admin/")
  def self.platform?(route) = route.defaults[:controller].start_with?("platform/")

  # Each segment is filled with its own name, because the request must be
  # turned away before any parameter is read.
  def path_for(route) = route.format(route.required_parts.index_with(&:to_s))

  it "allows only routes that exist to skip their credential" do
    endpoints = self.class.routes.map { |route| self.class.endpoint(route) }

    expect((self.class.tenantless + self.class.sessionless) - endpoints).to be_empty
  end

  routes.reject { |route| (tenantless + sessionless).include?(endpoint(route)) }.each do |route|
    if tenant_admin?(route)
      it "rejects #{route.verb} #{route.path.spec} without a staff session" do
        # A body goes as JSON, so the session check rather than the media type
        # check answers. Rails rewrites a GET sent as JSON into a POST.
        body = RequiresStaffSession::BODY_METHODS.include?(route.verb) ? { params: {}, as: :json } : {}
        process route.verb.downcase.to_sym, path_for(route), **body

        expect_failure(RequiresStaffSession::FAILURES.fetch(:missing_session))
      end
    elsif platform?(route)
      it "sends #{route.verb} #{route.path.spec} to sign in without a platform admin session" do
        # With a valid token, so the session check rather than forgery
        # protection answers.
        get new_platform_session_path
        process route.verb.downcase.to_sym, path_for(route), params: { authenticity_token: page_authenticity_token }

        expect(response).to redirect_to(new_platform_session_path)
      end
    else
      it "rejects #{route.verb} #{route.path.spec} without an api key" do
        process route.verb.downcase.to_sym, path_for(route)

        expect_failure(Tenancy::RequiresTenant::FAILURES.fetch(:missing_api_key))
      end
    end
  end
end
