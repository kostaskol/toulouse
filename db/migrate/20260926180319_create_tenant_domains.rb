class CreateTenantDomains < ActiveRecord::Migration[8.1]
  def change
    tenant_scoped_table :tenant_domains do |t|
      t.text :hostname, null: false
      t.boolean :is_primary, null: false, default: false
      t.datetime :verified_at
    end

    # Resolution must be unambiguous, so a hostname belongs to one tenant only.
    add_index :tenant_domains, :hostname, unique: true
    add_index :tenant_domains, [ :tenant_id, :is_primary ]
    add_index :tenant_domains, :tenant_id, unique: true, where: "is_primary",
              name: "index_tenant_domains_one_primary_per_tenant"

    add_check_constraint :tenant_domains, "hostname = lower(hostname)",
                         name: "tenant_domains_hostname_lowercase"
  end
end
