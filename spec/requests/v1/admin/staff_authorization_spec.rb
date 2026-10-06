require "rails_helper"

RSpec.describe "Staff authorization on tenant admin endpoints", type: :request do
  around do |example|
    with_routing do |routes|
      routes.draw do
        get "v1/admin/probe" => "permission_probe#show"
        patch "v1/admin/probe" => "permission_probe#update"
        delete "v1/admin/probe" => "permission_probe#destroy"
      end
      example.run
    end
  end

  let(:tenant) { create(:tenant) }
  let(:owner) { create(:staff, tenant:, role: "owner") }
  let(:staff) { create(:staff, tenant:, role: "staff") }

  def session_for(member) = create(:staff_session, tenant:, staff: member)

  it "lets a member with the permission through" do
    patch "/v1/admin/probe", params: {}, headers: staff_cookie(session_for(owner)), as: :json

    expect(response).to have_http_status(:no_content)
  end

  it "turns away a member without the permission" do
    patch "/v1/admin/probe", params: {}, headers: staff_cookie(session_for(staff)), as: :json

    expect_failure(AuthorizesStaff::FAILURES.fetch(:permission_denied))
  end

  it "lets any member through an action open to all staff" do
    get "/v1/admin/probe", headers: staff_cookie(session_for(staff))

    expect(response).to have_http_status(:no_content)
  end

  it "refuses to run an action that declares nothing" do
    expect { delete "/v1/admin/probe", headers: staff_cookie(session_for(owner)) }
      .to raise_error(AuthorizesStaff::UndeclaredAction)
  end
end
