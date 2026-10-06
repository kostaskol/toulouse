class CreateStaffSessions < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :staff_sessions do |t|
      t.references :staff, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.text :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false
    end

    # The session is how a tenant admin request finds its tenant, so there is
    # none yet. Only the row whose digest is current is visible, and read-only.
    reversible do |direction|
      direction.up do
        execute <<~SQL
          CREATE POLICY staff_session_lookup ON staff_sessions FOR SELECT
            USING (token_digest = NULLIF(current_setting('app.staff_session_digest', true), ''));
        SQL
      end

      direction.down { execute "DROP POLICY staff_session_lookup ON staff_sessions" }
    end
  end
end
