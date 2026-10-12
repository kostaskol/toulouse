class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :products, unique: [:slug] do |t|
      t.text :title, null: false
      t.text :slug, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.jsonb :option_names, null: false, default: []
      t.references :brand, type: :uuid, foreign_key: true
    end
  end
end
