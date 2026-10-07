require "rails_helper"

RSpec.describe Platform::Admin, :platform, type: :model do
  subject(:admin) { create(:platform_admin) }

  def code_at(time) = ROTP::TOTP.new(admin.otp_secret).at(time)

  it "uses the admins table in the platform schema" do
    expect(described_class.table_name).to eq("platform.admins")
  end

  it { is_expected.to have_many(:sessions).dependent(:delete_all) }
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to have_secure_password }

  it "normalizes the email" do
    expect(described_class.new(email: " Admin@Example.COM ").email).to eq("admin@example.com")
  end

  it "encrypts the TOTP secret" do
    stored = described_class.where(id: admin.id).select(:otp_secret).to_sql
    raw = ApplicationRecord.lease_connection.select_value(stored)

    expect(raw).not_to include(admin.otp_secret)
  end

  describe "#verify_otp" do
    it "accepts the current code" do
      expect(admin.verify_otp(code_at(Time.current))).to be(true)
    end

    it "accepts a code from one step either side, for clock drift" do
      expect(admin.verify_otp(code_at(described_class::OTP_DRIFT.ago))).to be(true)
      travel described_class::OTP_DRIFT * 2
      expect(admin.verify_otp(code_at(described_class::OTP_DRIFT.from_now))).to be(true)
    end

    it "refuses a code from further away" do
      expect(admin.verify_otp(code_at((described_class::OTP_DRIFT * 2).ago))).to be(false)
    end

    it "refuses a code already used" do
      code = code_at(Time.current)
      admin.verify_otp(code)

      expect(described_class.find(admin.id).verify_otp(code)).to be(false)
    end

    it "refuses a code older than one already used" do
      admin.verify_otp(code_at(Time.current))

      expect(admin.verify_otp(code_at(described_class::OTP_DRIFT.ago))).to be(false)
    end

    it "refuses a missing code" do
      expect(admin.verify_otp(nil)).to be(false)
    end
  end

  describe "failed logins" do
    def fail_times(count) = count.times { admin.record_failure }

    it "locks on the failure that reaches the limit" do
      fail_times(described_class::MAX_FAILURES - 1)
      expect(admin).not_to be_locked

      admin.record_failure
      expect(admin.reload.locked_until).to be_within(1.second).of(described_class::LOCKOUT.from_now)
    end

    it "unlocks once the lockout passes" do
      fail_times(described_class::MAX_FAILURES)
      travel described_class::LOCKOUT + 1.second

      expect(admin).not_to be_locked
    end

    it "starts counting again after the window" do
      fail_times(described_class::MAX_FAILURES - 1)
      travel described_class::WINDOW + 1.second
      admin.record_failure

      expect(admin).not_to be_locked
    end

    it "forgets failures once cleared" do
      fail_times(described_class::MAX_FAILURES - 1)
      admin.clear_failures
      admin.record_failure

      expect(admin).not_to be_locked
    end
  end

  describe ".provision" do
    let(:password) { SecureRandom.alphanumeric(16) }

    it "creates an admin with a new TOTP secret" do
      provisioned = described_class.provision(email: "new-#{admin.email}", password:)

      expect(provisioned).to be_persisted
      expect(provisioned.authenticate(password)).to eq(provisioned)
      expect(provisioned.otp_secret).to be_present
    end

    it "resets an existing admin's password and secret" do
      old_secret = admin.otp_secret
      provisioned = described_class.provision(email: admin.email, password:)

      expect(provisioned.id).to eq(admin.id)
      expect(provisioned.authenticate(password)).to eq(provisioned)
      expect(provisioned.otp_secret).not_to eq(old_secret)
    end

    it "lets the first code of the new secret through" do
      admin.verify_otp(code_at(Time.current))
      provisioned = described_class.provision(email: admin.email, password:)

      expect(provisioned.verify_otp(ROTP::TOTP.new(provisioned.otp_secret).now)).to be(true)
    end

    it "unlocks the admin" do
      described_class::MAX_FAILURES.times { admin.record_failure }

      expect(described_class.provision(email: admin.email, password:)).not_to be_locked
    end

    it "revokes the admin's sessions" do
      create(:platform_admin_session, admin:)
      described_class.provision(email: admin.email, password:)

      expect(Platform::Admin::Session.where(admin:)).to be_empty
    end

    it "raises on an invalid email" do
      expect { described_class.provision(email: "", password:) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
