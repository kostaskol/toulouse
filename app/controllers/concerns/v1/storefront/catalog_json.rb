module V1
  module Storefront
    module CatalogJson
      include ProductImageJson

      private

      def product_json(product)
        {
          id: product.id,
          title: product.title,
          slug: product.slug,
          description: product.description,
          option_names: product.option_names,
          brand: product.brand&.slice(:name, :slug),
          images: product.images.map { |image| image_json(image) },
          variants: product.active_variants.map { |variant| variant_json(variant) }
        }
      end

      def variant_json(variant)
        variant.slice(:id, :option_values, :sku, :price_cents, :compare_at_price_cents, :image_id)
               .merge(available: variant.available?)
      end
    end
  end
end
