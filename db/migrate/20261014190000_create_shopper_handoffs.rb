class CreateShopperHandoffs < ActiveRecord::Migration[8.1]
  def change
    # A platform admin shops through one email-less shopper per tenant, which
    # nobody can sign in to with a password.
    add_reference :shoppers, :platform_admin, type: :uuid, index: false,
                                              foreign_key: { to_table: "platform.admins" }
    add_index :shoppers, [:tenant_id, :platform_admin_id], unique: true
    change_column_null :shoppers, :email, true
    add_check_constraint :shoppers, "(platform_admin_id IS NULL) = (email IS NOT NULL)",
                         name: "shoppers_email_unless_admin_linked"
    add_check_constraint :shoppers, "staff_id IS NULL OR platform_admin_id IS NULL", name: "shoppers_one_link"
    remove_check_constraint :shoppers, "(staff_id IS NULL) = (password_digest IS NOT NULL)",
                            name: "shoppers_password_unless_linked"
    add_check_constraint :shoppers, "(staff_id IS NULL AND platform_admin_id IS NULL) = (password_digest IS NOT NULL)",
                         name: "shoppers_password_unless_linked"

    tenant_scoped_table :shopper_handoffs do |t|
      t.references :shopper, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.text :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.datetime :redeemed_at
    end
  end
end
