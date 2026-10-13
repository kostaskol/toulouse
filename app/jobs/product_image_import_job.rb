class ProductImageImportJob < ApplicationJob
  # @param entry [Product::Import::Entry]
  # @param urls [Array<String>]
  def perform(entry, urls); end
end
