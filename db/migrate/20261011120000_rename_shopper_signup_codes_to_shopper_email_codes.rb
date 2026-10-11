class RenameShopperSignupCodesToShopperEmailCodes < ActiveRecord::Migration[8.1]
  def change
    rename_table :shopper_signup_codes, :shopper_email_codes

    # The default only fills rows that exist now, which are all signup codes.
    add_column :shopper_email_codes, :purpose, :integer, null: false, default: 0
    change_column_default :shopper_email_codes, :purpose, from: 0, to: nil

    remove_index :shopper_email_codes, [:tenant_id, :email], unique: true
    add_index :shopper_email_codes, [:tenant_id, :purpose, :email], unique: true

    remove_check_constraint :shopper_email_codes, "email = lower(email)", name: "shopper_signup_codes_email_lowercase"
    add_check_constraint :shopper_email_codes, "email = lower(email)", name: "shopper_email_codes_email_lowercase"
  end
end
