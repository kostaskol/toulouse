require "rails_helper"

RSpec.describe "Tenant admin staff invites", type: :request do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:owner) { create(:staff, tenant:, role: "owner") }
  let(:email) { build(:staff).email }

  before do
    as_tenant(tenant) { tenant.setting.update!(sender_email: "orders@shop.example.com") }
    ActionMailer::Base.deliveries.clear
  end

  def invite(email:, as: owner)
    session = create(:staff_session, tenant:, staff: as)
    post "/admin/staff", params: { email: }, headers: staff_cookie(session), as: :json
    perform_enqueued_jobs
  end

  def invite_token(mail)
    URI(mail.text_part.body.to_s[%r{https?://\S+}]).fragment
  end

  def find_staff(email)
    as_tenant(tenant) { Staff.find_by(email:) }
  end

  it "creates a pending member with the staff role" do
    invite(email:)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["staff"]).to include("email" => email, "role" => "staff", "status" => "pending")
    expect(find_staff(email)).to have_attributes(role: "staff", status: "pending")
  end

  it "mails the invite to the email" do
    invite(email:)

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[email]])
  end

  it "stores the email in lowercase" do
    invite(email: email.upcase)

    expect(response.parsed_body.dig("staff", "email")).to eq(email)
  end

  context "when the email belongs to a pending member" do
    let!(:old_token) do
      invite(email:)
      invite_token(ActionMailer::Base.deliveries.last)
    end

    before do
      travel 1.second
      invite(email:)
    end

    it "answers with the same member" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("staff", "id")).to eq(find_staff(email).id)
    end

    it "mails a link that works and ends the older one" do
      new_token = invite_token(ActionMailer::Base.deliveries.last)

      expect(as_tenant(tenant) { Staff.find_by_token_for(:invite, old_token) }).to be_nil
      expect(as_tenant(tenant) { Staff.find_by_token_for(:invite, new_token) }).to eq(find_staff(email))
    end
  end

  it "refuses the email of an active member and mails nothing" do
    member = create(:staff, tenant:)

    invite(email: member.email)

    expect_failure(Admin::StaffController::FAILURES.fetch(:email_taken))
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "refuses a malformed email" do
    invite(email: "#{email}@")

    expect_failure(Admin::StaffController::FAILURES.fetch(:invalid_email))
  end

  it "refuses a blank email" do
    invite(email: "")

    expect_failure(Admin::StaffController::FAILURES.fetch(:invalid_email))
  end

  it "invites into the caller's store only" do
    other_tenant = create(:tenant)

    invite(email:)

    expect(as_tenant(other_tenant) { Staff.exists?(email:) }).to be(false)
  end

  it "turns away a member who is not an owner" do
    invite(email:, as: create(:staff, tenant:, role: "staff"))

    expect_failure(AuthorizesStaff::FAILURES.fetch(:permission_denied))
  end

  it "refuses a suspended store" do
    tenant.update!(status: "suspended")

    invite(email:)

    expect_failure(RequiresStaffSession::FAILURES.fetch(:tenant_suspended))
  end

  context "when the email belongs to a removed member" do
    let!(:member) { create(:staff, tenant:, status: "removed", role: "owner", password: nil) }

    before { invite(email: member.email) }

    it "makes the same member a pending staff member again, with no password" do
      expect(response).to have_http_status(:ok)
      expect(find_staff(member.email))
        .to have_attributes(id: member.id, status: "pending", role: "staff", password_digest: nil)
    end

    it "mails a link that accepts" do
      token = invite_token(ActionMailer::Base.deliveries.last)

      expect(as_tenant(tenant) { Staff.find_by_token_for(:invite, token) }).to eq(find_staff(member.email))
    end
  end

  it "invites into a pending store" do
    tenant.update!(status: "pending")

    invite(email:)

    expect(response).to have_http_status(:created)
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[email]])
  end

  describe "listing" do
    def list(as: owner)
      get "/admin/staff", headers: staff_cookie(create(:staff_session, tenant:, staff: as))
    end

    it "lists active and pending members, without removed ones" do
      pending = create(:staff, :pending, tenant:)
      create(:staff, tenant:, status: "removed")

      list

      expect(response.parsed_body["staff"]).to contain_exactly(
        { "id" => owner.id, "email" => owner.email, "role" => "owner", "status" => "active" },
        { "id" => pending.id, "email" => pending.email, "role" => "staff", "status" => "pending" }
      )
    end

    it "turns away a member who is not an owner" do
      list(as: create(:staff, tenant:))

      expect_failure(AuthorizesStaff::FAILURES.fetch(:permission_denied))
    end
  end

  describe "removing" do
    def remove(member, as: owner)
      delete "/admin/staff/#{member.id}", headers: staff_cookie(create(:staff_session, tenant:, staff: as))
    end

    it "removes an active member" do
      member = create(:staff, tenant:)

      remove(member)

      expect(response).to have_http_status(:no_content)
      expect(find_staff(member.email)).to be_removed
    end

    it "cancels a pending member's invite, so the link stops working" do
      member = create(:staff, :pending, tenant:)
      token = as_tenant(tenant) { member.generate_token_for(:invite) }

      remove(member)

      expect(response).to have_http_status(:no_content)
      expect(find_staff(member.email)).to be_removed
      acceptance = Staff::InviteAcceptance.call(slug: tenant.slug, token:, password: SecureRandom.alphanumeric(16))
      expect(acceptance.failure).to eq(:invalid_token)
    end

    it "refuses the last owner" do
      remove(owner)

      expect_failure(Admin::StaffController::FAILURES.fetch(:last_owner))
    end

    it "answers not found for a removed member" do
      remove(create(:staff, tenant:, status: "removed"))

      expect_failure(ApplicationController::FAILURES.fetch(:not_found))
    end

    it "turns away a member who is not an owner" do
      remove(owner, as: create(:staff, tenant:))

      expect_failure(AuthorizesStaff::FAILURES.fetch(:permission_denied))
    end
  end
end
