require "rails_helper"

RSpec.describe Tenancy::RequiresTenant, type: :controller do
  controller(ApplicationController) do
    include Tenancy::RequiresTenant

    def index
      head :no_content
    end
  end

  before { routes.draw { get "index" => "anonymous#index" } }

  # Controller specs reset CurrentAttributes around the request, so an assignment
  # made before `get` never reaches the action.
  def resolve_with(resolution)
    allow(Current).to receive(:resolution).and_return(resolution)
  end

  it "lets a resolved request through" do
    resolve_with(Tenancy::Resolution.resolved(create(:tenant)))

    get :index

    expect(response).to have_http_status(:no_content)
  end

  described_class::FAILURES.each do |reason, failure|
    it "maps #{reason} to its status and code" do
      resolve_with(Tenancy::Resolution.failed(reason))

      get :index

      expect(response).to have_http_status(failure.status)
      expect(response.parsed_body["errors"]).to eq(
        [ { "code" => failure.code, "message" => failure.message } ]
      )
    end
  end

  it "reports a missing key when nothing resolved at all" do
    failure = described_class::FAILURES.fetch(:missing_api_key)

    get :index

    expect(response).to have_http_status(failure.status)
    expect(response.parsed_body["errors"].first["code"]).to eq(failure.code)
  end

  it "returns errors as an array with one entry" do
    resolve_with(Tenancy::Resolution.failed(:invalid_api_key))

    get :index

    expect(response.parsed_body["errors"]).to be_an(Array)
    expect(response.parsed_body["errors"].size).to eq(1)
  end

  it "answers unauthorized for both api key failures" do
    codes = described_class::FAILURES.values_at(:missing_api_key, :invalid_api_key)

    expect(codes.map(&:status)).to all(eq(:unauthorized))
  end

  it "makes an inactive tenant indistinguishable from a missing one" do
    failure = described_class::FAILURES.fetch(:inactive)

    expect(failure.status).to eq(:not_found)
    expect(failure.message).not_to match(/suspend|pending|inactive/i)
  end

  it "names the credential header in the missing key message" do
    expect(described_class::FAILURES.fetch(:missing_api_key).message)
      .to include(Tenancy::Resolve::HEADER)
  end
end
