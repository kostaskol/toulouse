class AddWeightGramsToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :weight_grams, :integer
    add_check_constraint :product_variants, "weight_grams > 0", name: "product_variants_weight_positive"
  end
end
