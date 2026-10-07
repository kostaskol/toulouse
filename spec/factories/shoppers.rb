FactoryBot.define do
  factory :shopper, traits: [:tenant_scoped] do
    sequence(:email) { |n| "shopper-#{n}@example.com" }
    password { SecureRandom.alphanumeric(16) }

    trait :linked_to_staff do
      staff { association(:staff, tenant:, strategy: :create) }
      email { staff.email }
      password { nil }
    end
  end
end
