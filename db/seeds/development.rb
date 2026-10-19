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
Tenancy.with_tenant(demo) { demo.setting.update!(sender_email: "demo-store@example.com") }
seed_staff.call(demo, email: "owner@example.com", role: "owner")
seed_staff.call(demo, email: "staff@example.com", role: "staff")
seed_shopper.call(demo, email: "shopper@example.com")
seed_linked_shopper.call(demo, email: "owner@example.com")
# The storefront BFF reads this token from storefront/bff/.env.
Tenancy.with_tenant(demo) { demo.api_keys.find_or_create_by!(name: "Demo storefront") }

# The demo storefront's catalog. Prices are in cents. Each choice is a
# selectable spec. A sold_out entry empties every variant it matches.
demo_categories = {
  "Γυναικεία" => ["Φορέματα", "Μπλούζες"],
  "Ανδρικά" => ["Πουκάμισα", "Παντελόνια"],
  "Παπούτσια" => ["Σανδάλια", "Sneakers"],
  "Αξεσουάρ" => []
}
demo_products = [
  { title: "Ψάθινο καπέλο", brand: "Λινό", category: "Αξεσουάρ", price: 2500, specifications: { "Υλικό" => ["Άχυρο"] },
    description: "Πλεκτό στο χέρι από φυσικό άχυρο. Γείσο 8 εκ., ελαφρύ και για όλη τη μέρα." },
  { title: "Ψάθινη τσάντα ώμου", brand: "Λινό", category: "Αξεσουάρ", price: 4500,
    description: "Χωράει πετσέτα, βιβλίο και αντηλιακό.\n\n- Δερμάτινα χερούλια\n- Βαμβακερή φόδρα" },
  { title: "Λευκά δερμάτινα sneakers", brand: "Αιγαίο", category: "Sneakers", price: 8900, pre_discount: 11_000,
    choices: { "Νούμερο" => ["40", "41", "42", "43", "44"] },
    description: "Μαλακό δέρμα, λαστιχένια σόλα. Ταιριάζουν με όλα." },
  { title: "Δερμάτινα σανδάλια", brand: "Πήλιο", category: "Σανδάλια", price: 7500, stock: 0,
    choices: { "Νούμερο" => ["37", "38", "39", "40"] },
    description: "Χειροποίητα στο Πήλιο από φυτικά δεψασμένο δέρμα. Η σόλα παίρνει το σχήμα του ποδιού." },
  { title: "Βαμβακερό chino παντελόνι", brand: "Πήλιο", category: "Παντελόνια", price: 6500,
    choices: { "Μέγεθος" => ["30", "32", "34", "36"], "Χρώμα" => ["Μπεζ", "Navy"] },
    description: "Ίσια γραμμή, ελαφρύ βαμβάκι με λίγη ελαστικότητα." },
  { title: "Λινό πουκάμισο", brand: "Λινό", category: "Πουκάμισα", price: 5900,
    choices: { "Μέγεθος" => ["M", "L", "XL"], "Χρώμα" => ["Λευκό", "Γαλάζιο"] },
    specifications: { "Υλικό" => ["Λινό"] }, sold_out: [{ "Μέγεθος" => "XL", "Χρώμα" => "Γαλάζιο" }],
    description: "100% λινό, πλυμένο για πιο μαλακή αίσθηση.\n\n**Φροντίδα:** πλύσιμο στους 30°C." },
  { title: "Βαμβακερή μπλούζα", brand: "Αιγαίο", category: "Μπλούζες", price: 2900,
    choices: { "Μέγεθος" => ["S", "M", "L"], "Χρώμα" => ["Λευκό", "Μαύρο", "Τερακότα"] },
    specifications: { "Υλικό" => ["Οργανικό βαμβάκι"] },
    description: "Οργανικό βαμβάκι, φαρδιά γραμμή." },
  { title: "Μάξι φόρεμα με τιράντες", brand: "Αιγαίο", category: "Φορέματα", price: 6900, pre_discount: 9500,
    choices: { "Μέγεθος" => ["S", "M", "L"] }, specifications: { "Υλικό" => ["Βισκόζη"] },
    sold_out: [{ "Μέγεθος" => "S" }],
    description: "Ριχτό φόρεμα από βισκόζη, για το καλοκαίρι στο νησί." },
  { title: "Λινό φόρεμα Σαντορίνη", brand: "Λινό", category: "Φορέματα", price: 8900,
    choices: { "Μέγεθος" => ["S", "M", "L"], "Χρώμα" => ["Λευκό", "Άμμος"] }, specifications: { "Υλικό" => ["Λινό"] },
    description: "Το πιο αγαπημένο μας κομμάτι.\n\n- 100% λινό\n- Τσέπες στο πλάι\n- Ραμμένο στην Αθήνα" }
]

Tenancy.with_tenant(demo) do
  categories = demo_categories.each_with_index.flat_map do |(name, children), position|
    parent = Category.find_or_create_by!(name:, parent: nil) { |category| category.position = position }
    children = children.each_with_index.map do |child, child_position|
      Category.find_or_create_by!(name: child, parent:) { |category| category.position = child_position }
    end
    [parent, *children]
  end.index_by(&:name)

  # Created oldest first, since lists show the newest first.
  # A facet, so the demo filters by it.
  Specification.find_or_create_by!(name: "Υλικό") { |specification| specification.facet = true }
  { "Μέγεθος" => "size", "Χρώμα" => "colour", "Νούμερο" => "size" }.each do |name, kind|
    Specification.find_or_create_by!(name:) do |specification|
      specification.assign_attributes(kind:, multiple: false, selectable: true, facet: true)
    end
  end

  seed_product = lambda do |title:, brand:, category:, price:, description:, choices: {}, specifications: {},
                            pre_discount: nil, stock: 10, sold_out: []|
    next if Product.exists?(title:)

    combinations = choices.values.reduce([[]]) { |partial, values| partial.product(values).map(&:flatten) }
    variants = combinations.map do |values|
      chosen = choices.keys.zip(values).to_h
      quantity = sold_out.any? { |sold| sold <= chosen } ? 0 : stock
      { specifications: chosen.transform_values { |value| [value] }, price_cents: price,
        pre_discount_price_cents: pre_discount, vat_class: "standard", stock_quantity: quantity }
    end

    Product.create!(title:, description:, status: "published", specifications:,
                    brand: Brand.find_or_create_by!(name: brand), category: categories.fetch(category),
                    variants_attributes: variants)
  end
  demo_products.each { |product| seed_product.call(**product) }
end

# Same owner email in a second store, so the slug decides which one logs in.
suspended = seed_tenant.call(name: "Suspended Store", slug: "suspended-store", status: "suspended")
seed_staff.call(suspended, email: "owner@example.com", role: "owner")

# A new TOTP secret on every seed, so none is committed. Print the current code
# with bin/rails platform:admins:code EMAIL=admin@example.com.
Platform::Admin.provision(email: "admin@example.com", password:)
