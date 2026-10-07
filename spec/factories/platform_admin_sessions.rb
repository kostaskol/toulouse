FactoryBot.define do
  factory :platform_admin_session, class: "Platform::Admin::Session" do
    admin factory: :platform_admin
  end
end
