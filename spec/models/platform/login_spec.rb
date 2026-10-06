require "rails_helper"

RSpec.describe Platform::Login, :platform do
  let(:password) { SecureRandom.alphanumeric(16) }
  let!(:admin) { create(:platform_admin, password:) }

  def current_code = ROTP::TOTP.new(admin.otp_secret).now

  def log_in(email: admin.email, password: self.password, code: current_code)
    described_class.call(email:, password:, code:)
  end

  def wrong_password = SecureRandom.alphanumeric(16)

  def lock_out
    Platform::Admin::MAX_FAILURES.times { log_in(password: wrong_password) }
  end

  it "opens a session for the admin" do
    result = log_in

    expect(result.session.admin).to eq(admin)
    expect(result.session.token).to start_with(Platform::Admin::Session::TOKEN_PREFIX)
    expect(result.failure).to be_nil
  end

  it "matches the email whatever its case" do
    expect(log_in(email: admin.email.upcase).session).to be_present
  end

  describe "refusals that look alike" do
    it "refuses an unknown email" do
      expect(log_in(email: "missing-#{admin.email}", code: "").failure).to eq(:invalid_credentials)
    end

    it "refuses a wrong password" do
      expect(log_in(password: wrong_password).failure).to eq(:invalid_credentials)
    end

    it "refuses a wrong code" do
      wrong_code = ROTP::TOTP.new(admin.otp_secret).at(1.hour.ago)

      expect(log_in(code: wrong_code).failure).to eq(:invalid_credentials)
    end

    it "refuses a code already used" do
      code = current_code
      log_in(code:)

      expect(log_in(code:).failure).to eq(:invalid_credentials)
    end

    it "refuses blank credentials" do
      expect(log_in(email: nil, password: nil, code: nil).failure).to eq(:invalid_credentials)
    end

    it "refuses a locked admin with the right password and code" do
      lock_out

      expect(log_in.failure).to eq(:invalid_credentials)
    end

    # authenticate_by is what spends bcrypt time on an unknown email.
    it "spends a password hash on an unknown email" do
      allow(BCrypt::Password).to receive(:create).and_call_original

      log_in(email: "missing-#{admin.email}")

      expect(BCrypt::Password).to have_received(:create)
    end

    it "does not spend the code when the password is wrong" do
      code = current_code
      log_in(password: wrong_password, code:)

      expect(log_in(code:).session).to be_present
    end
  end

  describe "throttling" do
    it "counts a wrong code as a failure" do
      wrong_code = ROTP::TOTP.new(admin.otp_secret).at(1.hour.ago)
      Platform::Admin::MAX_FAILURES.times { log_in(code: wrong_code) }

      expect(admin.reload).to be_locked
    end

    it "does not extend the lock with attempts made during it" do
      lock_out
      locked_until = admin.reload.locked_until
      travel 1.minute
      log_in(password: wrong_password)

      expect(admin.reload.locked_until).to eq(locked_until)
    end

    it "lets the admin in once the lock passes" do
      lock_out
      travel Platform::Admin::LOCKOUT + 1.second

      expect(log_in.session).to be_present
    end

    it "forgets earlier failures on success" do
      (Platform::Admin::MAX_FAILURES - 1).times { log_in(password: wrong_password) }
      log_in
      log_in(password: wrong_password)

      expect(admin.reload).not_to be_locked
    end
  end
end
