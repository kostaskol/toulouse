# Sample data for calling the API locally. The Insomnia base environment uses
# the same slug, emails and password.
password = "toulouse-dev-password"

seed_tenant = lambda do |name:, slug:, status:|
  Tenant.find_or_create_by!(slug:) { |tenant| tenant.name = name }.tap { |tenant| tenant.update!(status:) }
end

seed_staff = lambda do |tenant, email:, role:|
  Tenancy.with_tenant(tenant) do
    Staff.find_or_initialize_by(email:).update!(role:, status: "active", password:)
  end
end

seed_shopper = lambda do |tenant, email:|
  Tenancy.with_tenant(tenant) { Shopper.find_or_initialize_by(email:).update!(password:) }
end

# Signs in on the storefront with the staff member's password.
seed_linked_shopper = lambda do |tenant, email:|
  Tenancy.with_tenant(tenant) do
    Shopper.find_or_initialize_by(email:).update!(staff: Staff.find_by!(email:), password: nil)
  end
end

demo = seed_tenant.call(name: "Demo Store", slug: "demo-store", status: "active")
seed_staff.call(demo, email: "owner@example.com", role: "owner")
seed_staff.call(demo, email: "staff@example.com", role: "staff")
seed_shopper.call(demo, email: "shopper@example.com")
seed_linked_shopper.call(demo, email: "owner@example.com")

# Same owner email in a second store, so the slug decides which one logs in.
suspended = seed_tenant.call(name: "Suspended Store", slug: "suspended-store", status: "suspended")
seed_staff.call(suspended, email: "owner@example.com", role: "owner")

# A new TOTP secret on every seed, so none is committed. Print the current code
# with bin/rails platform:admins:code EMAIL=admin@example.com.
Platform::Admin.provision(email: "admin@example.com", password:)
