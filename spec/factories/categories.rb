FactoryBot.define do
  factory :category, traits: [:tenant_scoped] do
    sequence(:name) { |n| "Category #{n}" }
  end
end
