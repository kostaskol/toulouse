FactoryBot.define do
  factory :platform_admin, class: "Platform::Admin" do
    sequence(:email) { |n| "platform-admin-#{n}@example.com" }
    password { SecureRandom.alphanumeric(16) }
    otp_secret { ROTP::Base32.random }
  end
end
