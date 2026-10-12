class CreateProductVariants < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :product_variants do |t|
      t.references :product, type: :uuid, null: false, foreign_key: true, index: false
      t.jsonb :option_values, null: false, default: {}
      t.text :sku
      t.text :barcode
      t.text :mpn
      t.integer :price_cents, null: false
      t.integer :compare_at_price_cents
      t.integer :vat_class, null: false
      t.integer :status, null: false, default: 0
    end

    # Deferred, so renaming options can swap names across variants inside one transaction.
    add_unique_constraint :product_variants, [:tenant_id, :product_id, :option_values], deferrable: :deferred,
                          name: "product_variants_unique_combination"
    add_index :product_variants, [:tenant_id, :sku], unique: true, where: "sku IS NOT NULL"

    add_check_constraint :product_variants, "price_cents >= 0", name: "product_variants_price_not_negative"
    add_check_constraint :product_variants, "compare_at_price_cents > price_cents",
                         name: "product_variants_compare_at_above_price"
  end
end
