# Sample data for calling the API locally. The Insomnia base environment uses
# the same slug, email and password.
password = "toulouse-dev-password"

seed_tenant = lambda do |name:, slug:, status:|
  Tenant.find_or_create_by!(slug:) { |tenant| tenant.name = name }.tap { |tenant| tenant.update!(status:) }
end

seed_staff = lambda do |tenant, email:, role:|
  Tenancy.with_tenant(tenant) do
    Staff.find_or_initialize_by(email:).update!(role:, status: "active", password:)
  end
end

demo = seed_tenant.call(name: "Demo Store", slug: "demo-store", status: "active")
seed_staff.call(demo, email: "owner@example.com", role: "owner")
seed_staff.call(demo, email: "staff@example.com", role: "staff")

# Same owner email in a second store, so the slug decides which one logs in.
suspended = seed_tenant.call(name: "Suspended Store", slug: "suspended-store", status: "suspended")
seed_staff.call(suspended, email: "owner@example.com", role: "owner")
