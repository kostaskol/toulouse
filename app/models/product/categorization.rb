class Product::Categorization < ApplicationRecord
  include Tenancy::Scoped

  has_paper_trail versions: { class_name: "Version" }

  belongs_to :product
  belongs_to :category
end
