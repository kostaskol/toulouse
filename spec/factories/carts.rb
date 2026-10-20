FactoryBot.define do
  factory :cart, traits: [:tenant_scoped] do
    shopper { association(:shopper, tenant:, strategy: :create) }
  end

  factory :cart_line, class: "Cart::Line", traits: [:tenant_scoped] do
    cart { association(:cart, tenant:) }
    variant { association(:product, :published, tenant:).variants.first }
    quantity { 1 }
  end
end
