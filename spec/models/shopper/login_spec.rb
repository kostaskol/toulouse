require "rails_helper"

RSpec.describe Shopper::Login do
  let(:tenant) { create(:tenant) }
  let(:password) { SecureRandom.alphanumeric(16) }
  let!(:shopper) { create(:shopper, tenant:, password:) }

  def log_in(email: shopper.email, password: self.password)
    as_tenant(tenant) { described_class.call(email:, password:) }
  end

  def wrong_password = SecureRandom.alphanumeric(16)

  def lock_out(email: shopper.email)
    LoginAttempt::MAX_FAILURES.times { log_in(email:, password: wrong_password) }
  end

  it "opens a session for the shopper" do
    result = log_in

    expect(result.session.shopper).to eq(shopper)
    expect(result.session.token).to start_with(Shopper::Session::TOKEN_PREFIX)
    expect(result.failure).to be_nil
  end

  it "matches the email whatever its case" do
    expect(log_in(email: shopper.email.upcase).session).to be_present
  end

  describe "a staff-linked shopper" do
    let(:staff) { create(:staff, tenant:, password:) }
    let!(:linked) { create(:shopper, :linked_to_staff, tenant:, staff:) }

    it "signs in with the staff password and gets a shopper session" do
      result = log_in(email: linked.email)

      expect(result.session).to be_a(Shopper::Session)
      expect(result.session.shopper).to eq(linked)
    end

    it "is refused while the staff member is pending" do
      as_tenant(tenant) { staff.update!(status: "pending") }

      expect(log_in(email: linked.email).failure).to eq(:invalid_credentials)
    end

    it "shares the failure counter with tenant admin login" do
      (LoginAttempt::MAX_FAILURES - 1).times do
        Staff::Login.call(slug: tenant.slug, email: staff.email, password: wrong_password)
      end

      expect(log_in(email: linked.email, password: wrong_password).failure).to eq(:too_many_attempts)
    end
  end

  describe "refusals that look alike" do
    it "refuses an unknown email" do
      expect(log_in(email: "missing-#{shopper.email}").failure).to eq(:invalid_credentials)
    end

    it "refuses a wrong password" do
      expect(log_in(password: wrong_password).failure).to eq(:invalid_credentials)
    end

    it "refuses a shopper of another tenant" do
      other = create(:shopper, tenant: create(:tenant), password:)

      expect(log_in(email: other.email).failure).to eq(:invalid_credentials)
    end

    it "refuses staff who have no linked shopper" do
      staff = create(:staff, tenant:, password:)

      expect(log_in(email: staff.email).failure).to eq(:invalid_credentials)
    end

    it "refuses blank credentials" do
      expect(log_in(email: nil, password: nil).failure).to eq(:invalid_credentials)
    end

    it "spends a password hash on an unknown email" do
      allow(BCrypt::Password).to receive(:create).and_call_original

      log_in(email: "missing-#{shopper.email}")

      expect(BCrypt::Password).to have_received(:create)
    end
  end

  describe "throttling" do
    it "locks the email on the failure that reaches the limit" do
      (LoginAttempt::MAX_FAILURES - 1).times { log_in(password: wrong_password) }
      result = log_in(password: wrong_password)

      expect(result.failure).to eq(:too_many_attempts)
      expect(result.locked_until).to be_within(1.second).of(LoginAttempt::LOCKOUT.from_now)
    end

    it "refuses the right password while locked" do
      lock_out

      expect(log_in.failure).to eq(:too_many_attempts)
    end

    it "locks an unknown email the same way" do
      email = "missing-#{shopper.email}"
      results = Array.new(LoginAttempt::MAX_FAILURES) { log_in(email:) }

      expect(results.last.failure).to eq(:too_many_attempts)
    end

    it "forgets earlier failures on success" do
      (LoginAttempt::MAX_FAILURES - 1).times { log_in(password: wrong_password) }
      log_in

      expect(log_in(password: wrong_password).failure).to eq(:invalid_credentials)
    end

    it "does not count blank credentials" do
      LoginAttempt::MAX_FAILURES.times { log_in(password: nil) }

      expect(log_in.session).to be_present
    end
  end
end
