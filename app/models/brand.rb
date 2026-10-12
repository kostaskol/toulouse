class Brand < ApplicationRecord
  include Tenancy::Scoped
  include Sluggable

  has_paper_trail versions: { class_name: "Version" }

  has_many :products, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :tenant_id }

  private

  def slug_source = name
end
