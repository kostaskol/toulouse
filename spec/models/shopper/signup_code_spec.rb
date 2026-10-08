require "rails_helper"

RSpec.describe Shopper::SignupCode, :as_tenant, type: :model do
  let(:email) { build(:shopper).email }

  def wrong_code(code) = ((code.to_i + 1) % (10**described_class::DIGITS)).to_s.rjust(described_class::DIGITS, "0")

  it "uses the shopper_signup_codes table" do
    expect(described_class.table_name).to eq("shopper_signup_codes")
  end

  describe ".issue" do
    it "returns a code of the configured length" do
      expect(described_class.issue(email)).to match(/\A\d{#{described_class::DIGITS}}\z/o)
    end

    it "stores a keyed digest rather than the code" do
      code = described_class.issue(email)

      stored = described_class.find_by(email:)
      expect(stored.code_digest).to eq(described_class.digest(code))
      expect(stored.code_digest).not_to eq(OpenSSL::Digest::SHA256.hexdigest(code))
    end

    it "stores the email in lowercase" do
      described_class.issue(email.upcase)

      expect(described_class.sole.email).to eq(email)
    end

    it "replaces an earlier code for the email" do
      first = described_class.issue(email)
      described_class.find_by(email:).refusal(wrong_code(first))
      second = described_class.issue(email)

      stored = described_class.sole
      expect(stored.attempts).to eq(0)
      expect(stored.refusal(second)).to be_nil
    end
  end

  describe "#refusal" do
    let!(:code) { described_class.issue(email) }
    let(:signup_code) { described_class.find_by(email:) }

    it "accepts the code" do
      expect(signup_code.refusal(code)).to be_nil
    end

    it "refuses a wrong code" do
      expect(signup_code.refusal(wrong_code(code))).to eq(:wrong_code)
    end

    it "refuses an expired code" do
      travel described_class::EXPIRY + 1.second

      expect(signup_code.refusal(code)).to eq(:expired)
    end

    it "refuses the right code once the tries are used up" do
      described_class::MAX_ATTEMPTS.times { signup_code.refusal(wrong_code(code)) }

      expect(signup_code.refusal(code)).to eq(:out_of_attempts)
    end

    it "counts tries held by stale copies of the row" do
      copies = Array.new(described_class::MAX_ATTEMPTS) { described_class.find(signup_code.id) }
      copies.each { |copy| copy.refusal(wrong_code(code)) }

      expect(signup_code.refusal(code)).to eq(:out_of_attempts)
    end
  end

  describe ".expired" do
    it "holds codes past their expiry" do
      described_class.issue(email)
      travel described_class::EXPIRY + 1.second

      expect(described_class.expired.count).to eq(1)
    end
  end
end
