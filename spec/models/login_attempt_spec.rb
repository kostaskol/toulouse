require "rails_helper"

RSpec.describe LoginAttempt, :as_tenant, type: :model do
  let(:email) { attributes_for(:login_attempt)[:email] }

  def fail_times(count)
    Array.new(count) { described_class.record_failure(email) }.last
  end

  it { is_expected.to belong_to(:tenant) }

  it "matches an email whatever case it is given in" do
    described_class.record_failure(email.upcase)

    expect(described_class.find_by(email:).failed_count).to eq(1)
  end

  describe ".record_failure" do
    it "counts failures without locking below the limit" do
      expect(fail_times(described_class::MAX_FAILURES - 1)).to be_nil
      expect(described_class.find_by(email:).failed_count).to eq(described_class::MAX_FAILURES - 1)
    end

    it "locks on the failure that reaches the limit" do
      locked_until = fail_times(described_class::MAX_FAILURES)

      expect(locked_until).to be_within(1.second).of(described_class::LOCKOUT.from_now)
    end

    it "starts counting again once locked" do
      fail_times(described_class::MAX_FAILURES)

      expect(described_class.find_by(email:).failed_count).to eq(0)
    end

    it "starts counting again after the window passes with no failure" do
      fail_times(described_class::MAX_FAILURES - 1)
      travel described_class::WINDOW + 1.second

      expect(described_class.record_failure(email)).to be_nil
      expect(described_class.find_by(email:).failed_count).to eq(1)
    end

    it "keeps counting within the window" do
      fail_times(described_class::MAX_FAILURES - 1)
      travel described_class::WINDOW - 1.second

      expect(described_class.record_failure(email)).to be_present
    end

    it "keeps each tenant's count apart" do
      fail_times(described_class::MAX_FAILURES - 1)

      as_tenant(create(:tenant)) { expect(described_class.record_failure(email)).to be_nil }
    end
  end

  describe ".locked_until" do
    it "is nil for an email with no failures" do
      expect(described_class.locked_until(email)).to be_nil
    end

    it "returns the end of an active lock" do
      locked_until = fail_times(described_class::MAX_FAILURES)

      expect(described_class.locked_until(email)).to eq(locked_until)
    end

    it "is nil once the lock has passed" do
      fail_times(described_class::MAX_FAILURES)
      travel described_class::LOCKOUT + 1.second

      expect(described_class.locked_until(email)).to be_nil
    end
  end

  describe ".clear" do
    it "forgets the email's failures" do
      fail_times(described_class::MAX_FAILURES - 1)
      described_class.clear(email)

      expect(described_class.find_by(email:)).to be_nil
    end
  end

  describe ".expired" do
    it "includes a row whose window and lock have passed" do
      fail_times(described_class::MAX_FAILURES)
      travel described_class::WINDOW + 1.second

      expect(described_class.expired.count).to eq(1)
    end

    it "excludes a row inside its window" do
      fail_times(1)

      expect(described_class.expired).to be_empty
    end
  end
end
