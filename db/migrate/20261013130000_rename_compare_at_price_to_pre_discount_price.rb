class RenameCompareAtPriceToPreDiscountPrice < ActiveRecord::Migration[8.1]
  def change
    rename_column :product_variants, :compare_at_price_cents, :pre_discount_price_cents

    reversible do |direction|
      direction.up do
        execute "ALTER TABLE product_variants RENAME CONSTRAINT product_variants_compare_at_above_price " \
                "TO product_variants_pre_discount_above_price"
      end
      direction.down do
        execute "ALTER TABLE product_variants RENAME CONSTRAINT product_variants_pre_discount_above_price " \
                "TO product_variants_compare_at_above_price"
      end
    end
  end
end
