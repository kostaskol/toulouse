require "rails_helper"

RSpec.describe Tenancy::Resolve do
  subject(:middleware) { described_class.new(app) }

  let(:seen) { [] }
  let(:app) { ->(_env) { seen << Current.resolution; [ 204, {}, [] ] } }

  def env_for(headers = {}, path = "/")
    Rack::MockRequest.env_for(path).merge(headers)
  end

  def captured_log(level: Logger::DEBUG)
    log = StringIO.new
    logger = ActiveSupport::Logger.new(log)
    logger.level = level
    allow(Rails).to receive(:logger).and_return(logger)
    yield
    log.string
  end

  it "names the rack env key after the wire header" do
    expect(described_class::ENV_KEY).to eq("HTTP_X_API_KEY")
    expect(described_class::HEADER).to eq("X-Api-Key")
  end

  it "writes a resolution for a valid key" do
    key = create(:tenant_api_key)

    middleware.call(env_for(described_class::ENV_KEY => key.token))

    expect(seen.last).to be_resolved
    expect(seen.last.tenant).to eq(key.tenant)
  end

  it "calls the app and writes a failure when there is no key" do
    status, = middleware.call(env_for)

    expect(status).to eq(204)
    expect(seen.last.reason).to eq(:missing_api_key)
  end

  it "never renders an error itself" do
    status, = middleware.call(env_for(described_class::ENV_KEY => "  "))

    expect(status).to eq(204)
  end

  it "does not resolve from the Host header" do
    domain = create(:tenant_domain, is_primary: true)

    middleware.call(env_for("HTTP_HOST" => domain.hostname))

    expect(seen.last).not_to be_resolved
    expect(seen.last.reason).to eq(:missing_api_key)
  end

  it "ignores tenant_id in the query string and the body" do
    key = create(:tenant_api_key)
    other = create(:tenant)
    env = Rack::MockRequest.env_for(
      "/?tenant_id=#{other.id}",
      method: "POST",
      input: { tenant_id: other.id }.to_json,
      "CONTENT_TYPE" => "application/json"
    ).merge(described_class::ENV_KEY => key.token)

    middleware.call(env)

    expect(seen.last.tenant).to eq(key.tenant)
  end

  it "rejects a header value with invalid byte sequences rather than raising" do
    token = Tenant::ApiKey::TOKEN_PREFIX.dup.force_encoding(Encoding::ASCII_8BIT) + "\xC3".b

    expect { middleware.call(env_for(described_class::ENV_KEY => token)) }.not_to raise_error
    expect(seen.last.reason).to eq(:invalid_api_key)
  end

  it "logs the discriminated failure reason with the path" do
    logged = captured_log { middleware.call(env_for({}, "/up")) }

    expect(logged).to include("missing_api_key")
    expect(logged).to include("/up")
  end

  # Health checks and scanners send no credential, so warning on them would bury
  # the failures that mean a real credential was rejected.
  it "keeps a credential-free request below warn" do
    logged = captured_log(level: Logger::WARN) { middleware.call(env_for({}, "/up")) }

    expect(logged).to be_empty
  end

  it "warns when a presented credential is rejected" do
    key = create(:tenant_api_key)

    logged = captured_log(level: Logger::WARN) do
      middleware.call(env_for(described_class::ENV_KEY => key.token_prefix))
    end

    expect(logged).to include("invalid_api_key")
  end

  it "warns when the tenant is not active" do
    key = create(:tenant_api_key, tenant: create(:tenant, status: :suspended))

    logged = captured_log(level: Logger::WARN) do
      middleware.call(env_for(described_class::ENV_KEY => key.token))
    end

    expect(logged).to include("inactive")
  end

  it "logs nothing for a resolved request" do
    key = create(:tenant_api_key)

    logged = captured_log { middleware.call(env_for(described_class::ENV_KEY => key.token)) }

    expect(logged).to be_empty
  end

  it "is registered in the application middleware stack" do
    expect(Rails.application.middleware.map(&:name)).to include(described_class.name)
  end
end
