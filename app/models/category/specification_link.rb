# A spec that products in a category and the categories below it should state.
class Category::SpecificationLink < ApplicationRecord
  include Tenancy::Scoped

  has_paper_trail versions: { class_name: "Version" }

  belongs_to :category, inverse_of: :links
  belongs_to :specification, inverse_of: :category_links
end
