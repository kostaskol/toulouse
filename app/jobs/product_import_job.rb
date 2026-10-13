class ProductImportJob < ApplicationJob
  queue_with_priority 10

  # @param import [Product::Import]
  def perform(import)
    import.run!
  end
end
