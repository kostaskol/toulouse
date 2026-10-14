class CreateSpecifications < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :specifications, unique: [:key] do |t|
      t.text :name, null: false
      t.text :key, null: false
      t.integer :position, null: false, default: 0
      t.boolean :facet, null: false, default: false
      t.integer :mode, null: false, default: 0
    end

    tenant_scoped_table :product_specification_values do |t|
      t.references :product, type: :uuid, null: false, foreign_key: true, index: false
      t.references :variant, type: :uuid, foreign_key: { to_table: :product_variants }, index: false
      t.references :specification, type: :uuid, null: false, foreign_key: true, index: false
      t.text :value, null: false
      t.integer :position, null: false, default: 0
    end

    # A product's own values and each variant's are separate sets, so a null variant must collide with itself.
    add_index :product_specification_values, [:tenant_id, :product_id, :variant_id, :specification_id, :value],
              unique: true, nulls_not_distinct: true, name: "index_product_specification_values_unique"
    add_index :product_specification_values, [:tenant_id, :variant_id], where: "variant_id IS NOT NULL",
                                                    name: "index_product_specification_values_on_variant"
    add_index :product_specification_values, [:tenant_id, :specification_id],
              name: "index_product_specification_values_on_specification"
  end
end
