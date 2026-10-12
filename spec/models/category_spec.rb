require "rails_helper"

RSpec.describe Category, :as_tenant, type: :model do
  let(:root) { create(:category) }
  let(:child) { create(:category, parent: root) }
  let(:grandchild) { create(:category, parent: child) }

  it "lists its own id and every id below it" do
    grandchild
    create(:category)

    expect(root.subtree_ids).to contain_exactly(root.id, child.id, grandchild.id)
  end

  it "refuses to move under a category below it" do
    root.parent = grandchild

    expect(root).not_to be_valid
    expect(root.errors.details[:parent_id]).to eq([{ error: :invalid_parent }])
  end

  it "refuses to move under itself" do
    root.parent_id = root.id

    expect(root).not_to be_valid
  end

  it "moves under a category in another branch" do
    other = create(:category)

    expect(child.update(parent: other)).to be(true)
  end

  it "refuses a parent of another tenant" do
    other = create(:category, tenant: create(:tenant))

    expect(build(:category, parent_id: other.id)).not_to be_valid
  end

  it "refuses a malformed parent id rather than moving to the top" do
    child.parent_id = "#{root.id}x"

    expect(child).not_to be_valid
  end

  describe "removal" do
    it "is refused while categories sit below it" do
      child

      expect(root.destroy).to be(false)
      expect(described_class.exists?(root.id)).to be(true)
    end

    it "drops its product links and keeps the products" do
      product = create(:product, category_ids: [root.id])
      root.destroy!

      expect(product.reload.category_ids).to be_empty
    end
  end
end
