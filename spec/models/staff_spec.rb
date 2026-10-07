require "rails_helper"

RSpec.describe Staff, :as_tenant, type: :model do
  let(:password) { SecureRandom.alphanumeric(16) }

  it { is_expected.to belong_to(:tenant) }

  it "uses the staff table" do
    expect(described_class.table_name).to eq("staff")
  end

  describe "email" do
    it "is stored lowercased and stripped" do
      staff = create(:staff, email: " Owner@Example.COM ")

      expect(staff.email).to eq("owner@example.com")
    end

    it "is found whatever case it is looked up in" do
      staff = create(:staff, email: "owner@example.com")

      expect(described_class.find_by(email: "OWNER@example.com")).to eq(staff)
    end

    it "is required" do
      expect(build(:staff, email: nil)).not_to be_valid
    end

    it "must look like an email address" do
      expect(build(:staff, email: "owner")).not_to be_valid
    end

    it "is unique within a tenant regardless of case" do
      create(:staff, email: "owner@example.com")

      expect(build(:staff, email: "OWNER@example.com")).not_to be_valid
    end
  end

  describe "password" do
    it "authenticates by email and password within the tenant" do
      staff = create(:staff, email: "owner@example.com", password:)

      expect(described_class.authenticate_by(email: "Owner@example.com", password:)).to eq(staff)
    end

    it "is required once active" do
      expect(build(:staff, password: nil)).not_to be_valid
    end

    it "may be absent while pending" do
      expect(build(:staff, :pending)).to be_valid
    end

    it "cannot be removed by activating a pending member without one" do
      staff = create(:staff, :pending)

      expect(staff.update(status: "active")).to be(false)
    end

    it "does not authenticate a pending member with no password" do
      staff = create(:staff, :pending)

      expect(described_class.authenticate_by(email: staff.email, password: "")).to be_nil
    end

    it "must match its confirmation when one is given" do
      expect(build(:staff, password:, password_confirmation: password.reverse)).not_to be_valid
    end

    it "rejects a password longer than bcrypt reads" do
      too_long = "a" * (ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED + 1)

      expect(build(:staff, password: too_long)).not_to be_valid
    end

    it "is not stored in plain text" do
      staff = create(:staff, password:)

      expect(staff.password_digest).not_to include(password)
    end
  end

  describe "role" do
    it "defaults to staff" do
      expect(described_class.new.role).to eq("staff")
    end

    it "can be owner" do
      expect(create(:staff, role: "owner")).to be_owner
    end

    it "rejects an unknown role" do
      staff = build(:staff)
      staff.role = "nonsense"

      expect(staff).not_to be_valid
    end
  end

  describe "permissions" do
    let(:owner) { described_class.new(role: "owner") }
    let(:staff) { described_class.new(role: "staff") }

    it "lets an owner manage staff" do
      expect(owner.permissions).to contain_exactly(:manage_staff)
      expect(owner.can?(:manage_staff)).to be(true)
    end

    it "keeps staff from managing staff" do
      expect(staff.permissions).to be_empty
      expect(staff.can?(:manage_staff)).to be(false)
    end

    it "knows which permissions exist" do
      expect(described_class.permission?(:manage_staff)).to be(true)
      expect(described_class.permission?(:no_such_permission)).to be(false)
    end
  end

  describe "status" do
    it "defaults to pending" do
      expect(described_class.new.status).to eq("pending")
    end

    it "rejects an unknown status" do
      staff = build(:staff)
      staff.status = "nonsense"

      expect(staff).not_to be_valid
    end
  end

  describe "database constraints" do
    def insert_staff(tenant:, **attributes)
      as_tenant(tenant) do
        described_class.insert!({
          tenant_id: tenant.id, email: "owner@example.com",
          password_digest: BCrypt::Password.create(password),
          status: described_class.statuses[:active]
        }.merge(attributes))
      end
    end

    it "rejects the same email twice in one tenant" do
      tenant = create(:tenant)
      insert_staff(tenant: tenant)

      expect { insert_staff(tenant: tenant) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same email in two tenants" do
      insert_staff(tenant: create(:tenant))

      expect { insert_staff(tenant: create(:tenant)) }.not_to raise_error
    end

    # A string update skips the model's normalization, which insert! still applies.
    it "rejects an email that is not lowercase" do
      staff = create(:staff)

      expect { described_class.where(id: staff.id).update_all("email = upper(email)") }
        .to raise_error(ActiveRecord::StatementInvalid, /staff_email_lowercase/)
    end

    it "rejects an active member with no password digest" do
      expect { insert_staff(tenant: create(:tenant), password_digest: nil) }
        .to raise_error(ActiveRecord::StatementInvalid, /staff_password_unless_pending/)
    end

    it "allows a pending member with no password digest" do
      pending = { password_digest: nil, status: described_class.statuses[:pending] }

      expect { insert_staff(tenant: create(:tenant), **pending) }.not_to raise_error
    end

    it "defaults role to staff and status to pending when callbacks are bypassed" do
      tenant = create(:tenant)
      as_tenant(tenant) { described_class.insert!({ tenant_id: tenant.id, email: "owner@example.com" }) }

      staff = as_tenant(tenant) { described_class.sole }
      expect(staff).to be_staff.and be_pending
    end
  end
end
