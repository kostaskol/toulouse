class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :categories, unique: [:slug] do |t|
      t.text :name, null: false
      t.text :slug, null: false
      t.references :parent, type: :uuid, foreign_key: { to_table: :categories }, index: false
      t.integer :position, null: false, default: 0
    end

    add_index :categories, [:tenant_id, :parent_id, :position]

    tenant_scoped_table :product_categorizations, unique: [[:category_id, :product_id]] do |t|
      t.references :product, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :category, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
    end
  end
end
