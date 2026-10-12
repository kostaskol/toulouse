class CreateBrands < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :brands, unique: [:name, :slug] do |t|
      t.text :name, null: false
      t.text :slug, null: false
    end
  end
end
