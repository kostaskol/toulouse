require "rails_helper"

RSpec.describe "CORS", type: :request do
  let(:admin_origin) { Rails.configuration.x.admin_origin }

  def preflight(path, origin)
    options path, headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => "POST",
      "Access-Control-Request-Headers" => "Content-Type"
    }
  end

  it "admits the tenant admin origin with credentials" do
    preflight("/v1/admin/session", admin_origin)

    expect(response.headers["Access-Control-Allow-Origin"]).to eq(admin_origin)
    expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")
  end

  it "admits no other origin" do
    preflight("/v1/admin/session", "#{admin_origin}.evil")

    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end

  it "admits nothing outside tenant admin" do
    preflight("/up", admin_origin)

    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end
end
