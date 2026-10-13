module Admin
  module CatalogJson
    include ProductImageJson

    private

    def product_json(product)
      {
        id: product.id,
        title: product.title,
        slug: product.slug,
        description: product.description,
        status: product.status,
        option_names: product.option_names,
        brand: product.brand && brand_json(product.brand),
        category_ids: product.category_ids,
        images: product.images.map { |image| image_json(image) },
        variants: product.variants.map { |variant| variant_json(variant) }
      }
    end

    def variant_json(variant)
      variant.slice(
        :id, :option_values, :sku, :barcode, :mpn, :price_cents, :pre_discount_price_cents, :vat_class, :status,
        :track_stock, :stock_quantity, :allow_oversell, :image_id
      )
    end

    def brand_json(brand)
      brand.slice(:id, :name, :slug)
    end
  end
end
