class MoveVariantChoicesOntoSpecifications < ActiveRecord::Migration[8.1]
  # No data moves, because no merchant exists yet.
  def change
    remove_column :products, :option_names, :jsonb, null: false, default: []
    remove_unique_constraint :product_variants, [:tenant_id, :product_id, :option_values],
                             deferrable: :deferred, name: "product_variants_unique_combination"
    remove_column :product_variants, :option_values, :jsonb, null: false, default: {}
    remove_reference :product_variants, :image, type: :uuid, index: false,
                                                foreign_key: { to_table: :product_images, on_delete: :nullify }

    add_column :specifications, :kind, :integer, null: false, default: 0
    add_column :specifications, :multiple, :boolean, null: false, default: true
    add_column :specifications, :selectable, :boolean, null: false, default: false

    add_reference :product_images, :specification, type: :uuid, foreign_key: true, index: false
    add_column :product_images, :value, :text
    add_index :product_images, [:tenant_id, :specification_id], where: "specification_id IS NOT NULL"
    add_check_constraint :product_images, "(specification_id IS NULL) = (value IS NULL)",
                         name: "product_images_link_complete"
  end
end
