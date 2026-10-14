# One value of a spec, stated by a product or overridden by one of its variants.
class Product::SpecificationValue < ApplicationRecord
  include Tenancy::Scoped

  has_paper_trail versions: { class_name: "Version" }

  belongs_to :product
  belongs_to :variant, class_name: "Product::Variant", optional: true
  belongs_to :specification

  # Built after the owner validates, so validation never runs on it.
  before_save { self.product ||= variant&.product }
end
