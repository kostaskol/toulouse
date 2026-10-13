class Product::Import < ApplicationRecord
  include Tenancy::Scoped

  belongs_to :staff, optional: true
  has_many :entries, foreign_key: :product_import_id, inverse_of: :import, dependent: :delete_all

  enum :status, { queued: 0, running: 1, done: 2, failed: 3 }, validate: true
end
