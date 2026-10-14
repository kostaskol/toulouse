FactoryBot.define do
  factory :specification, traits: [:tenant_scoped] do
    sequence(:name) { |n| "Spec #{n}" }
  end
end
