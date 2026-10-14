class Brand < ApplicationRecord
  include Tenancy::Scoped
  include Sluggable

  has_paper_trail versions: { class_name: "Version" }

  has_many :products, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  after_update_commit :refresh_product_search, if: :saved_change_to_name?

  private

  def refresh_product_search
    ids = products.ids
    ProductSearchRefreshJob.perform_later(ids) if ids.any?
  end

  def slug_source = name
end
