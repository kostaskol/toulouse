FactoryBot.define do
  factory :product, traits: [:tenant_scoped] do
    sequence(:title) { |n| "Product #{n}" }
    category { association(:category, tenant:) }

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
    # A selectable value of its own, so a product can hold several variants. attributes_for has no tenant to hold it.
    specifications do
      next {} unless tenant

      choice = Tenancy.with_tenant(tenant) do
        Specification.find_or_create_by!(name: "Variant") do |definition|
          definition.assign_attributes(multiple: false, selectable: true)
        end
      end
      { choice.name => [SecureRandom.hex(4)] }
    end
  end

  factory :product_image, class: "Product::Image", traits: [:tenant_scoped] do
    product { association(:product, tenant:) }
    file { Tenancy.with_tenant(tenant) { Product::Image.attachable(ImageFiles.image_file, product.slug) } }
  end
end
