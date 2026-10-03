FactoryBot.define do
  factory :tenant_domain, class: "Tenant::Domain", traits: [ :tenant_scoped ] do
    sequence(:hostname) { |n| "shop-#{n}.example.com" }
    is_primary { false }
  end
end
