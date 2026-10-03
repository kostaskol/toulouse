require "rails_helper"

RSpec.describe Tenant::Setting, :as_tenant, type: :model do
  let(:tenant) { Current.tenant }

  it { is_expected.to belong_to(:tenant) }

  it "is created alongside its tenant" do
    expect(described_class.sole.tenant_id).to eq(tenant.id)
  end

  it "starts with an empty settings object" do
    expect(create(:tenant).setting.settings).to eq({})
  end

  it "stores and reads back nested values" do
    tenant.setting.update!(settings: { "currency" => "EUR", "limits" => { "orders" => 10 } })

    expect(tenant.setting.reload.settings).to eq("currency" => "EUR", "limits" => { "orders" => 10 })
  end

  it "is removed when its tenant is deleted" do
    expect { tenant.destroy }.to change(described_class, :count).by(-1)
  end

  describe "database constraints" do
    def insert_setting(tenant:, settings: {})
      described_class.insert!({ tenant_id: tenant.id, settings: settings })
    end

    it "rejects a second settings row for the same tenant" do
      expect { insert_setting(tenant: tenant) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a settings value that is not a JSON object" do
      tenant.setting.delete

      expect { insert_setting(tenant: tenant, settings: [ 1, 2 ]) }
        .to raise_error(ActiveRecord::StatementInvalid, /tenant_settings_is_object/)
    end
  end
end
