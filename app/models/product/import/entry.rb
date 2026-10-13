class Product::Import::Entry < ApplicationRecord
  include Tenancy::Scoped

  belongs_to :import, class_name: "Product::Import", foreign_key: :product_import_id, inverse_of: :entries
  belongs_to :product, optional: true

  enum :result, { created: 0, updated: 1, skipped: 2, failed: 3 }, validate: true

  # One statement, so parallel image jobs never overwrite each other's errors.
  #
  # @param detail [Hash]
  def add_image_error!(detail)
    self.class.where(id:).update_all(["image_errors = image_errors || ?::jsonb", [detail].to_json])
  end
end
