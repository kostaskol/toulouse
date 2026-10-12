class CreateVersions < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :versions do |t|
      t.text :item_type, null: false
      t.uuid :item_id, null: false
      t.text :event, null: false
      t.text :whodunnit
      t.jsonb :object
      t.jsonb :object_changes
    end

    add_index :versions, [:tenant_id, :item_type, :item_id]
  end
end
