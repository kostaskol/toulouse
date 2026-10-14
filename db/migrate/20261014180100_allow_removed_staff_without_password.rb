class AllowRemovedStaffWithoutPassword < ActiveRecord::Migration[8.1]
  # A cancelled invite is kept as removed, and it never had a password.
  def change
    remove_check_constraint :staff, "status = 0 OR password_digest IS NOT NULL", name: "staff_password_unless_pending"
    # Status 1 is active.
    add_check_constraint :staff, "status <> 1 OR password_digest IS NOT NULL", name: "staff_password_when_active"
  end
end
