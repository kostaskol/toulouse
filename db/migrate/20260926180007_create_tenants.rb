class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants, id: :uuid, default: "uuidv7()" do |t|
      t.text :name, null: false
      t.text :slug, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :tenants, :slug, unique: true

    add_check_constraint :tenants, "slug ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'",
                         name: "tenants_slug_format"
  end
end
