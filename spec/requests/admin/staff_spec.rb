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

  it "invites into a pending store" do
    tenant.update!(status: "pending")

    invite(email:)

    expect(response).to have_http_status(:created)
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[email]])
  end
end
