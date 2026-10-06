require "rails_helper"

RSpec.describe Staff::Login do
  let(:tenant) { create(:tenant) }
  let(:password) { SecureRandom.alphanumeric(16) }
  let!(:staff) { create(:staff, tenant:, password:) }

  def log_in(slug: tenant.slug, email: staff.email, password: self.password)
    described_class.call(slug:, email:, password:)
  end

  def wrong_password = SecureRandom.alphanumeric(16)

  def lock_out
    LoginAttempt::MAX_FAILURES.times { log_in(password: wrong_password) }
  end

  it "opens a session for the staff member" do
    result = log_in

    expect(result.session.staff).to eq(staff)
    expect(result.session.token).to start_with(Staff::Session::TOKEN_PREFIX)
    expect(result.failure).to be_nil
  end

  it "matches the email whatever its case" do
    expect(log_in(email: staff.email.upcase).session).to be_present
  end

  it "leaves no tenant current afterwards" do
    log_in

    expect(Current.tenant).to be_nil
  end

  it "opens a session for a suspended tenant" do
    tenant.update!(status: "suspended")

    expect(log_in.session).to be_present
  end

  describe "refusals that look alike" do
    it "refuses an unknown slug" do
      expect(log_in(slug: "#{tenant.slug}-missing").failure).to eq(:invalid_credentials)
    end

    it "refuses an unknown email" do
      expect(log_in(email: "missing-#{staff.email}").failure).to eq(:invalid_credentials)
    end

    it "refuses a wrong password" do
      expect(log_in(password: wrong_password).failure).to eq(:invalid_credentials)
    end

    it "refuses staff of another tenant" do
      other = create(:staff, tenant: create(:tenant), password:)

      expect(log_in(email: other.email).failure).to eq(:invalid_credentials)
    end

    it "refuses pending staff" do
      pending = create(:staff, :pending, tenant:)

      expect(log_in(email: pending.email).failure).to eq(:invalid_credentials)
    end

    it "refuses pending staff even with a password set" do
      as_tenant(tenant) { staff.update!(status: "pending") }

      expect(log_in.failure).to eq(:invalid_credentials)
    end

    it "refuses blank credentials" do
      expect(log_in(email: nil, password: nil).failure).to eq(:invalid_credentials)
    end

    # authenticate_by is what spends bcrypt time on an unknown email.
    it "spends a password hash on an unknown email" do
      allow(BCrypt::Password).to receive(:create).and_call_original

      log_in(email: "missing-#{staff.email}")

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

    it "does not extend the lock with attempts made during it" do
      lock_out
      locked_until = log_in.locked_until
      travel 1.minute
      log_in(password: wrong_password)

      expect(log_in.locked_until).to eq(locked_until)
    end

    it "locks an unknown email the same way" do
      email = "missing-#{staff.email}"
      results = Array.new(LoginAttempt::MAX_FAILURES) { log_in(email:) }

      expect(results.last.failure).to eq(:too_many_attempts)
    end

    it "lets the right password in once the lock passes" do
      lock_out
      travel LoginAttempt::LOCKOUT + 1.second

      expect(log_in.session).to be_present
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
