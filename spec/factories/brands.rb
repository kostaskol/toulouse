FactoryBot.define do
  factory :brand, traits: [:tenant_scoped] do
    sequence(:name) { |n| "Brand #{n}" }
  end
end
