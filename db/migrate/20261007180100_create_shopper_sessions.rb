class CreateShopperSessions < ActiveRecord::Migration[8.1]
  # No digest lookup policy, unlike staff sessions. The API key has already
  # made the tenant current when the token is read.
  def change
    tenant_scoped_table :shopper_sessions do |t|
      t.references :shopper, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.text :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
    end
  end
end
