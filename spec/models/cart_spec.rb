require "rails_helper"

RSpec.describe Cart do
  let(:tenant) { as_tenant }
  let(:variant) { create(:product, :published).variants.first.tap { |v| v.update!(stock_quantity: 3) } }

  before { tenant }

  describe ".for_guest" do
    it "opens the guest cart its token belongs to" do
      cart = described_class.create!

      expect(described_class.for_guest(cart.token)).to eq(cart)
    end

    it "refuses an expired cart" do
      token = described_class.create!.token
      travel described_class::GUEST_IDLE_TIMEOUT + 1.second

      expect(described_class.for_guest(token)).to be_nil
    end

    it "refuses a token of another type without a query" do
      token = create(:shopper_session).token

      expect(count_queries { expect(described_class.for_guest(token)).to be_nil }).to eq(0)
    end
  end

  describe "#add! and #set!" do
    let(:cart) { create(:cart) }

    it "adds to the line" do
      cart.add!(variant, 1)
      cart.add!(variant, 1)

      expect(cart.lines.sole.quantity).to eq(2)
    end

    it "refuses to set a line that is not in the cart" do
      expect { cart.set!(variant, 1) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "clamps by the stock of the variant it was given, not a stale copy on the line" do
      cart.add!(variant, 1)
      Product::Variant.where(id: variant.id).update_all(stock_quantity: 0)

      expect { cart.add!(variant, 1) }.not_to raise_error
    end

    it "sets the line" do
      cart.add!(variant, 2)
      cart.set!(variant, 1)

      expect(cart.lines.sole.quantity).to eq(1)
    end

    it "clamps to the stock left and says so" do
      expect(cart.add!(variant, variant.stock_quantity + 1)).to be(true)
      expect(cart.lines.sole.quantity).to eq(variant.stock_quantity)
    end

    it "takes any quantity of a variant that allows oversell" do
      variant.update!(allow_oversell: true)

      expect(cart.add!(variant, variant.stock_quantity + 1)).to be(false)
    end

    it "moves a guest cart's expiry" do
      guest = described_class.create!
      travel 1.day

      guest.add!(variant, 1)

      expect(guest.reload.expires_at).to be_within(1.second).of(described_class::GUEST_IDLE_TIMEOUT.from_now)
    end
  end

  describe ".merge_guest!" do
    let(:shopper) { create(:shopper) }
    let(:guest) { described_class.create! }

    it "sums a variant in both carts, past the stock left" do
      guest.add!(variant, variant.stock_quantity)
      create(:cart, shopper:).add!(variant, 1)

      expect(described_class.merge_guest!(guest.token, shopper)).to be(true)
      expect(described_class.find_by(shopper:).lines.sole.quantity).to eq(variant.stock_quantity + 1)
    end

    it "hands the guest cart's lines to a shopper with no cart, and says nothing" do
      guest.add!(variant, 1)

      expect(described_class.merge_guest!(guest.token, shopper)).to be(false)
      expect(described_class.find_by(shopper:).lines.sole.variant).to eq(variant)
    end

    it "deletes the guest cart" do
      described_class.merge_guest!(guest.token, shopper)

      expect(described_class.exists?(guest.id)).to be(false)
    end

    it "does nothing without a guest cart" do
      expect(described_class.merge_guest!(nil, shopper)).to be(false)
      expect(described_class.exists?(shopper:)).to be(false)
    end
  end
end
