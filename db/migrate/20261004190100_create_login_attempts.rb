class CreateLoginAttempts < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :login_attempts, unique: [:email] do |t|
      t.text :email, null: false
      t.integer :failed_count, null: false, default: 0
      t.datetime :last_failed_at
      t.datetime :locked_until
    end

    add_check_constraint :login_attempts, "email = lower(email)", name: "login_attempts_email_lowercase"
  end
end
