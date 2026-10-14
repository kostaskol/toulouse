FactoryBot.define do
  factory :shopper_handoff, class: "Shopper::Handoff", traits: [:tenant_scoped] do
    shopper { association(:shopper, tenant:, strategy: :create) }
  end
end
