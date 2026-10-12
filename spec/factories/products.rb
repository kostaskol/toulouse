FactoryBot.define do
  factory :product, traits: [:tenant_scoped] do
    sequence(:title) { |n| "Product #{n}" }
    sequence(:option_names) { |n| ["Option #{n}"] }

    # Every product is created with a variant.
    after(:build) do |product|
      Tenancy.with_tenant(product.tenant) do
        next unless product.variants.empty?

        product.variants << FactoryBot.build(:product_variant, tenant: product.tenant, product:)
      end
    end

    trait :published do
      status { "published" }
    end
  end

  factory :product_variant, class: "Product::Variant", traits: [:tenant_scoped] do
    product { association(:product, tenant:) }
    sequence(:price_cents) { |n| n * 100 }
    vat_class { Product::Variant.vat_classes.keys.first }
    option_values { Array(product&.option_names).index_with { SecureRandom.hex(4) } }
  end
end
