RSpec.shared_examples "a tenant-scoped endpoint" do
  it "serves the record to its own tenant" do
    perform_request(create(:tenant_api_key, tenant: record.tenant))

    expect(response).to be_successful
  end

  # The status is left to the endpoint's own spec, since an index answers
  # another tenant with an empty list rather than a 404.
  it "neither reveals nor changes the record for another tenant" do
    original = record.attributes
    # The id is left out because the request itself carries it, and error
    # pages echo the path.
    revealing = original.except("id").values.grep(String)

    perform_request(create(:tenant_api_key, tenant: create(:tenant)))

    expect(revealing).to all(satisfy { |value| response.body.exclude?(value) })
    expect(as_tenant(record.tenant) { record.reload.attributes }).to eq(original)
  end
end
