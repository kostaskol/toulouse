FactoryBot.define do
  factory :tenant_domain, class: "Tenant::Domain" do
    tenant
    sequence(:hostname) { |n| "shop-#{n}.example.com" }
    is_primary { false }
  end
end
