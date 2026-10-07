class CreateShoppers < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :shoppers, unique: [:email] do |t|
      t.text :email, null: false
      t.text :password_digest
      t.references :staff, type: :uuid, foreign_key: true, index: { unique: true }
    end

    add_check_constraint :shoppers, "email = lower(email)", name: "shoppers_email_lowercase"

    # A staff-linked shopper signs in with the staff password.
    add_check_constraint :shoppers, "(staff_id IS NULL) = (password_digest IS NOT NULL)",
                         name: "shoppers_password_unless_linked"
  end
end
