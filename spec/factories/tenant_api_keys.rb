FactoryBot.define do
  factory :tenant_api_key, class: "Tenant::ApiKey", traits: [ :tenant_scoped ] do
    sequence(:name) { |n| "Key #{n}" }
  end
end
