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
        specifications: specifications_json(product),
        brand: product.brand && brand_json(product.brand),
        category_id: product.category_id,
        in_comparison_feeds: product.in_comparison_feeds,
        images: product.images.map { |image| image_json(image) },
        variants: product.variants.map { |variant| variant_json(variant) }
      }
    end

    def variant_json(variant)
      variant.slice(
        :id, :sku, :barcode, :mpn, :price_cents, :pre_discount_price_cents, :vat_class, :status, :track_stock,
        :stock_quantity, :allow_oversell, :weight_grams
      ).merge(selection: variant.selection, specifications: specifications_json(variant))
    end

    def specifications_json(record)
      record.specification_entries.map do |specification, values|
        { id: specification.id, name: specification.name, values: }
      end
    end

    def specification_json(specification)
      specification.slice(:id, :name, :position, :facet, :mode, :kind, :multiple, :selectable)
    end

    def brand_json(brand)
      brand.slice(:id, :name, :slug)
    end
  end
end
