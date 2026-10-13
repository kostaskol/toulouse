class CreateProductImports < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :product_imports do |t|
      t.references :staff, type: :uuid, foreign_key: { on_delete: :nullify }, index: false
      t.boolean :dry_run, null: false, default: false
      t.integer :status, null: false, default: 0
      t.text :file
      t.integer :images_pending, null: false, default: 0
      t.jsonb :error_details, null: false, default: []
      t.datetime :finished_at
    end

    # Two imports at once could create the same category twice. Statuses 0 and 1 are queued and running.
    add_index :product_imports, :tenant_id, unique: true, where: "status IN (0, 1)",
                                            name: "index_product_imports_one_active_per_tenant"

    tenant_scoped_table :product_import_entries, unique: [[:product_import_id, :position]] do |t|
      t.references :product_import, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :product, type: :uuid, foreign_key: true, index: false
      t.integer :position, null: false
      t.text :handle, null: false
      t.integer :rows, array: true, null: false, default: []
      t.integer :result, null: false
      t.jsonb :error_details, null: false, default: []
      t.jsonb :warnings, null: false, default: []
      t.jsonb :image_errors, null: false, default: []
      t.text :created_brands, array: true, null: false, default: []
      t.text :created_categories, array: true, null: false, default: []
    end
  end
end
