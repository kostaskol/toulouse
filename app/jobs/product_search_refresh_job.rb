class ProductSearchRefreshJob < ApplicationJob
  # @param product_ids [Array<String>]
  def perform(product_ids)
    # Locked and reloaded, so an edit saved while the job runs is not overwritten by a stale copy.
    Product.where(id: product_ids).find_each { |product| product.with_lock { Product::Search.refresh(product) } }
  end
end
