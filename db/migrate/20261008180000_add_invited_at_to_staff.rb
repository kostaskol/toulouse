class AddInvitedAtToStaff < ActiveRecord::Migration[8.1]
  def change
    add_column :staff, :invited_at, :datetime
  end
end
