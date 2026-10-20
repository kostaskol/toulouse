class CreateCarts < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :carts, unique: [:shopper_id] do |t|
      t.references :shopper, type: :uuid, index: false, foreign_key: { on_delete: :cascade }
      t.text :token_digest, index: { unique: true }
      t.datetime :expires_at
      t.check_constraint "(shopper_id IS NULL) = (token_digest IS NOT NULL)", name: "carts_shopper_or_token"
      t.check_constraint "(token_digest IS NULL) = (expires_at IS NULL)", name: "carts_token_expires"
    end
    add_index :carts, [:tenant_id, :expires_at], where: "expires_at IS NOT NULL"

    tenant_scoped_table :cart_lines, unique: [[:cart_id, :variant_id]] do |t|
      t.references :cart, type: :uuid, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :variant, type: :uuid, null: false, foreign_key: { to_table: :product_variants, on_delete: :cascade }
      t.integer :quantity, null: false
      t.check_constraint "quantity > 0", name: "cart_lines_quantity_positive"
    end
  end
end
