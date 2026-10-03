require "rails_helper"

RSpec.describe "Tenant-scoped endpoint isolation", type: :request do
  around do |example|
    with_routing do |routes|
      routes.draw do
        get "probe/domains/:id" => "tenant_probe#domain"
        patch "probe/domains/:id" => "tenant_probe#update_domain"
      end
      example.run
    end
  end

  let(:record) { create(:tenant_domain) }

  def headers_for(key)
    { Tenancy::RequiresTenant::HEADER => key.token }
  end

  context "when reading" do
    it_behaves_like "a tenant-scoped endpoint" do
      def perform_request(api_key)
        get "/probe/domains/#{record.id}", headers: headers_for(api_key)
      end
    end
  end

  context "when writing" do
    it_behaves_like "a tenant-scoped endpoint" do
      def perform_request(api_key)
        patch "/probe/domains/#{record.id}",
              params: { hostname: attributes_for(:tenant_domain)[:hostname] },
              headers: headers_for(api_key)
      end
    end
  end
end
