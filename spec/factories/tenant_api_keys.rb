FactoryBot.define do
  factory :tenant_api_key, class: "Tenant::ApiKey" do
    tenant
    sequence(:name) { |n| "Key #{n}" }
  end
end
