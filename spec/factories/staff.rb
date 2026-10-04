FactoryBot.define do
  factory :staff, traits: [ :tenant_scoped ] do
    sequence(:email) { |n| "staff-#{n}@example.com" }
    password { SecureRandom.alphanumeric(16) }
    status { "active" }

    trait :pending do
      password { nil }
      status { "pending" }
    end
  end
end
