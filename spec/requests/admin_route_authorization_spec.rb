require "rails_helper"

RSpec.describe "Staff authorization on every tenant admin route" do
  # Signs the staff member in, so there is nobody to authorize yet.
  def self.exempt = ["v1/admin/sessions#create"]
  def self.routes = Rails.application.routes.routes.reject(&:internal).select { |route| tenant_admin?(route) }
  def self.tenant_admin?(route) = route.defaults[:controller]&.start_with?("v1/admin/")
  def self.endpoint(route) = "#{route.defaults[:controller]}##{route.defaults[:action]}"

  it "exempts only routes that exist" do
    expect(self.class.exempt - self.class.routes.map { |route| self.class.endpoint(route) }).to be_empty
  end

  routes.reject { |route| exempt.include?(endpoint(route)) }.each do |route|
    it "declares who may call #{endpoint(route)}" do
      controller = "#{route.defaults[:controller]}_controller".camelize.constantize

      expect(controller.staff_authorization(route.defaults[:action])).not_to be_nil
    end
  end
end
