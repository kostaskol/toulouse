require "rails_helper"

RSpec.describe Tenancy::RequiresTenant, type: :controller do
  controller(ApplicationController) do
    # described_class is unavailable here: the block is class_exec'd on the controller.
    include Tenancy::RequiresTenant # rubocop:disable RSpec/DescribedClass

    def index
      render json: { tenant_id: Current.tenant.id }
    end
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
      post "index" => "anonymous#index"
    end
  end

  def present_key(token)
    request.headers[described_class::HEADER] = token
  end

  def captured_log(level: Logger::DEBUG)
    log = StringIO.new
    logger = ActiveSupport::Logger.new(log)
    logger.level = level
    allow(Rails).to receive(:logger).and_return(logger)
    yield
    log.string
  end

  def expect_failure(reason)
    failure = described_class::FAILURES.fetch(reason)

    expect(response).to have_http_status(failure.status)
    expect(response.parsed_body["errors"]).to eq(
      [ { "code" => failure.code, "message" => failure.message } ]
    )
  end

  it "reads the credential from X-Api-Key" do
    expect(described_class::HEADER).to eq("X-Api-Key")
  end

  it "makes the key's tenant current for the action" do
    key = create(:tenant_api_key)
    present_key(key.token)

    get :index

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["tenant_id"]).to eq(key.tenant_id)
  end

  it "stamps last_used_at once the key's tenant is current" do
    key = create(:tenant_api_key)
    present_key(key.token)

    get :index

    expect(as_tenant(key.tenant) { key.reload.last_used_at }).to be_within(5.seconds).of(Time.current)
  end

  it "rejects a request with no key" do
    get :index

    expect_failure(:missing_api_key)
  end

  it "rejects an unrecognised key" do
    present_key(create(:tenant_api_key).token_prefix)

    get :index

    expect_failure(:invalid_api_key)
  end

  it "rejects a key whose tenant is not active" do
    present_key(create(:tenant_api_key, tenant: create(:tenant, status: :suspended)).token)

    get :index

    expect_failure(:inactive)
  end

  it "does not resolve from the Host header" do
    domain = create(:tenant_domain, is_primary: true)
    request.host = domain.hostname

    get :index

    expect_failure(:missing_api_key)
  end

  it "ignores tenant_id in the query string and the body" do
    key = create(:tenant_api_key)
    other = create(:tenant)
    present_key(key.token)

    post :index, params: { tenant_id: other.id }, as: :json

    expect(response.parsed_body["tenant_id"]).to eq(key.tenant_id)
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
    expect(described_class::FAILURES.fetch(:missing_api_key).message).to include(described_class::HEADER)
  end

  it "logs the discriminated failure reason with the path" do
    logged = captured_log { get :index }

    expect(logged).to include("missing_api_key")
    expect(logged).to include("/index")
  end

  it "keeps a credential-free request below warn" do
    logged = captured_log(level: Logger::WARN) { get :index }

    expect(logged).to be_empty
  end

  it "warns when a presented credential is rejected" do
    present_key(create(:tenant_api_key).token_prefix)

    logged = captured_log(level: Logger::WARN) { get :index }

    expect(logged).to include("invalid_api_key")
  end

  it "warns when the tenant is not active" do
    present_key(create(:tenant_api_key, tenant: create(:tenant, status: :suspended)).token)

    logged = captured_log(level: Logger::WARN) { get :index }

    expect(logged).to include("inactive")
  end

  it "logs nothing for a resolved request" do
    present_key(create(:tenant_api_key).token)

    logged = captured_log { get :index }

    expect(logged).to be_empty
  end
end
