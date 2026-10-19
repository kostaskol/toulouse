class AddInComparisonFeedsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :in_comparison_feeds, :boolean, null: false, default: true
  end
end
