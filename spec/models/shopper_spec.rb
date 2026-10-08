require "rails_helper"

RSpec.describe Shopper, :as_tenant, type: :model do
  let(:password) { SecureRandom.alphanumeric(16) }

  it { is_expected.to belong_to(:tenant) }
  it { is_expected.to belong_to(:staff).optional }
  it { is_expected.to have_many(:sessions) }

  describe "email" do
    it "is stored lowercased and stripped" do
      email = attributes_for(:shopper)[:email]
      shopper = create(:shopper, email: " #{email.upcase} ")

      expect(shopper.email).to eq(email)
    end

    it "is required" do
      expect(build(:shopper, email: nil)).not_to be_valid
    end

    it "must look like an email address" do
      expect(build(:shopper, email: attributes_for(:shopper)[:email].delete("@"))).not_to be_valid
    end

    it "is unique within a tenant regardless of case" do
      shopper = create(:shopper)

      expect(build(:shopper, email: shopper.email.upcase)).not_to be_valid
    end

    it "may repeat in another tenant" do
      shopper = create(:shopper)

      expect(build(:shopper, tenant: create(:tenant), email: shopper.email)).to be_valid
    end
  end

  describe "password" do
    it "is required when not linked to staff" do
      expect(build(:shopper, password: nil)).not_to be_valid
    end

    it "is refused when linked to staff" do
      expect(build(:shopper, :linked_to_staff, password:)).not_to be_valid
    end

    it "may be absent when linked to staff" do
      expect(build(:shopper, :linked_to_staff)).to be_valid
    end

    it "rejects a password longer than bcrypt reads" do
      too_long = "a" * (ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED + 1)

      expect(build(:shopper, password: too_long)).not_to be_valid
    end

    it "authenticates by email and password within the tenant" do
      shopper = create(:shopper, password:)

      expect(described_class.authenticate_by(email: shopper.email, password:)).to eq(shopper)
    end
  end

  describe "staff link" do
    it "allows one shopper per staff member" do
      shopper = create(:shopper, :linked_to_staff)

      expect(build(:shopper, :linked_to_staff, staff: shopper.staff)).not_to be_valid
    end
  end

  describe "database constraints" do
    let(:tenant) { create(:tenant) }

    def insert_shopper(**attributes)
      as_tenant(tenant) do
        described_class.insert!({
          tenant_id: tenant.id, email: attributes_for(:shopper)[:email],
          password_digest: BCrypt::Password.create(password)
        }.merge(attributes))
      end
    end

    it "rejects the same email twice in one tenant" do
      email = attributes_for(:shopper)[:email]
      insert_shopper(email:)

      expect { insert_shopper(email:) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    # A string update skips the model's normalization, which insert! still applies.
    it "rejects an email that is not lowercase" do
      shopper = create(:shopper, tenant:)

      expect { as_tenant(tenant) { described_class.where(id: shopper.id).update_all("email = upper(email)") } }
        .to raise_error(ActiveRecord::StatementInvalid, /shoppers_email_lowercase/)
    end

    it "rejects a shopper with neither a password nor a staff link" do
      expect { insert_shopper(password_digest: nil) }
        .to raise_error(ActiveRecord::StatementInvalid, /shoppers_password_unless_linked/)
    end

    it "rejects a staff-linked shopper with its own password" do
      staff = create(:staff, tenant:)

      expect { insert_shopper(staff_id: staff.id) }
        .to raise_error(ActiveRecord::StatementInvalid, /shoppers_password_unless_linked/)
    end

    it "rejects a second shopper for one staff member" do
      staff = create(:staff, tenant:)
      insert_shopper(staff_id: staff.id, password_digest: nil)

      expect { insert_shopper(staff_id: staff.id, password_digest: nil) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
