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

  describe "specification links" do
    let(:size) { create(:specification) }

    it "replaces every link and keeps the rows that stay" do
      colour = create(:specification)
      root.update!(specification_links: [
        { specification_id: size.id, required: true }, { specification_id: colour.id }
      ])
      kept = root.links.first
      root.update!(specification_links: [{ "specification_id" => size.id.upcase, "required" => false }])

      expect(root.reload.links).to contain_exactly(have_attributes(id: kept.id, required: false))
    end

    it "refuses a spec of another tenant" do
      other = create(:specification, tenant: create(:tenant))

      expect(root.update(specification_links: [{ specification_id: other.id }])).to be(false)
      expect(root.errors.details[:specification_links]).to eq([{ error: :invalid }])
    end

    it "refuses the same spec twice" do
      expect(root.update(specification_links: [{ specification_id: size.id }] * 2)).to be(false)
    end

    it "requires the specs of every category above" do
      root.update!(specification_links: [{ specification_id: size.id, required: true }])
      child.update!(specification_links: [{ specification_id: create(:specification).id }])

      expect(grandchild.required_specifications).to eq([size])
    end

    it "goes with its category" do
      root.update!(specification_links: [{ specification_id: size.id }])
      root.destroy!

      expect(Category::SpecificationLink.count).to eq(0)
    end

    it "goes with its spec" do
      root.update!(specification_links: [{ specification_id: size.id }])
      size.destroy!

      expect(root.links.reload).to be_empty
    end
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

    it "is refused while products sit in it" do
      create(:product, category: root)

      expect(root.destroy).to be(false)
      expect(described_class.exists?(root.id)).to be(true)
    end
  end
end
