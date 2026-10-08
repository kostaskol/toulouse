class CreateShopperSignupCodes < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :shopper_signup_codes, unique: [:email] do |t|
      t.text :email, null: false
      t.text :code_digest, null: false
      t.datetime :expires_at, null: false
      t.integer :attempts, null: false, default: 0
    end

    add_check_constraint :shopper_signup_codes, "email = lower(email)", name: "shopper_signup_codes_email_lowercase"
  end
end
