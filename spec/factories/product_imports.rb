FactoryBot.define do
  factory :product_import, class: "Product::Import", traits: [:tenant_scoped] do
    staff { association(:staff, tenant:) }
    file { "" }
  end
end
