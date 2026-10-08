FactoryBot.define do
  factory :shopper_session, class: "Shopper::Session", traits: [:tenant_scoped] do
    shopper { association(:shopper, tenant:, strategy: :create) }
  end
end
