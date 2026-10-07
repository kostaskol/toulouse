class CreatePlatformAdmins < ActiveRecord::Migration[8.1]
  def change
    # The app role gets no usage on this schema, so no platform table is
    # reachable from a storefront or tenant admin request.
    create_schema :platform

    create_table "platform.admins", id: :uuid, default: "uuidv7()" do |t|
      t.text :email, null: false, index: { unique: true }
      t.text :password_digest, null: false
      t.text :otp_secret, null: false
      t.datetime :last_otp_at
      t.integer :failed_count, null: false, default: 0
      t.datetime :last_failed_at
      t.datetime :locked_until
      t.timestamps
    end

    create_table "platform.admin_sessions", id: :uuid, default: "uuidv7()" do |t|
      t.references :admin, type: :uuid, null: false,
                           foreign_key: { to_table: "platform.admins", on_delete: :cascade }
      t.text :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
      t.timestamps
    end

    reversible do |direction|
      # Production still connects every role as the owner, which needs no grants.
      direction.up { execute Platform::DatabaseRole.grants_sql unless platform_role_is_owner? }
    end
  end

  private

  def platform_role_is_owner?
    Platform::DatabaseRole.username == select_value("SELECT current_user")
  end
end
