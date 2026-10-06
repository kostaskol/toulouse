FactoryBot.define do
  factory :staff_session, class: "Staff::Session", traits: [ :tenant_scoped ] do
    staff { association(:staff, tenant:) }
  end
end
