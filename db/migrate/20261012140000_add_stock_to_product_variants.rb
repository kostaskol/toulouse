class AddStockToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :track_stock, :boolean, null: false, default: true
    add_column :product_variants, :stock_quantity, :integer, null: false, default: 0
    add_column :product_variants, :allow_oversell, :boolean, null: false, default: false

    add_column :versions, :reason, :text
  end
end
