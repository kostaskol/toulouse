class CreateStaff < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :staff, unique: [ :email ] do |t|
      t.text :email, null: false
      t.text :password_digest
      t.integer :role, null: false, default: 0
      t.integer :status, null: false, default: 0
    end

    # Keeps the per-tenant unique index case-insensitive for writes that skip
    # the model's normalization.
    add_check_constraint :staff, "email = lower(email)", name: "staff_email_lowercase"

    # Status 0 is pending: invited, no password set yet.
    add_check_constraint :staff, "status = 0 OR password_digest IS NOT NULL",
                         name: "staff_password_unless_pending"
  end
end
