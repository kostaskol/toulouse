class MoveProductCategoryOntoProducts < ActiveRecord::Migration[8.1]
  # No data moves, because no merchant exists yet.
  def up
    drop_table :product_categorizations
    add_reference :products, :category, type: :uuid, null: false, foreign_key: true, index: false
    add_index :products, [:tenant_id, :category_id]
  end

  def down
    remove_reference :products, :category, foreign_key: true, index: false
    tenant_scoped_table :product_categorizations, unique: [[:category_id, :product_id]] do |t|
      t.references :product, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :category, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
    end
  end
end
