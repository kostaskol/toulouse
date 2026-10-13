class CreateProductImages < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :product_images do |t|
      t.references :product, type: :uuid, null: false, foreign_key: true, index: false
      t.text :alt
      t.integer :position, null: false, default: 0
    end

    add_index :product_images, [:tenant_id, :product_id, :position]

    add_reference :product_variants, :image, type: :uuid, index: false,
                                             foreign_key: { to_table: :product_images, on_delete: :nullify }
  end
end
