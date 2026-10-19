class CreateCategorySpecificationLinks < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :category_specification_links, unique: [[:category_id, :specification_id]] do |t|
      t.references :category, type: :uuid, null: false, foreign_key: true, index: false
      t.references :specification, type: :uuid, null: false, foreign_key: true, index: false
      t.boolean :required, null: false, default: false
    end

    add_index :category_specification_links, [:tenant_id, :specification_id]
  end
end
