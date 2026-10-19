module V1
  module Storefront
    module CatalogJson
      include ProductImageJson

      private

      # What the storefront may show, with what its JSON reads.
      def catalog = Product.published.with_images.with_specifications(variants: :active_variants).includes(:brand)

      def product_json(product)
        {
          id: product.id,
          title: product.title,
          slug: product.slug,
          description: product.description,
          option_names: product.option_names,
          specifications: specifications_json(product),
          brand: product.brand&.slice(:name, :slug),
          category_id: product.category_id,
          images: product.images.map { |image| image_json(image) },
          variants: product.active_variants.map { |variant| variant_json(variant) }
        }
      end

      def variant_json(variant)
        variant.slice(:id, :option_values, :sku, :price_cents, :pre_discount_price_cents, :image_id)
               .merge(available: variant.available?, specifications: specifications_json(variant))
      end

      def specifications_json(record)
        record.specification_entries.map { |specification, values| { name: specification.name, values: } }
      end
    end
  end
end
