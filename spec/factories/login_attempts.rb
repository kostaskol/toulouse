FactoryBot.define do
  factory :login_attempt, traits: [ :tenant_scoped ] do
    sequence(:email) { |n| "staff-#{n}@example.com" }
  end
end
