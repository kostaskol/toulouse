# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_26_180646) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "tenant_api_keys", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.text "name", null: false
    t.text "token_prefix", null: false
    t.text "token_digest", null: false
    t.datetime "last_used_at"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "created_at"], name: "index_tenant_api_keys_on_tenant_id_and_created_at"
    t.index ["tenant_id"], name: "index_tenant_api_keys_on_tenant_id"
    t.index ["token_digest"], name: "index_tenant_api_keys_on_token_digest", unique: true
  end

  create_table "tenant_domains", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.text "hostname", null: false
    t.boolean "is_primary", default: false, null: false
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hostname"], name: "index_tenant_domains_on_hostname", unique: true
    t.index ["tenant_id", "is_primary"], name: "index_tenant_domains_on_tenant_id_and_is_primary"
    t.index ["tenant_id"], name: "index_tenant_domains_on_tenant_id"
    t.index ["tenant_id"], name: "index_tenant_domains_one_primary_per_tenant", unique: true, where: "is_primary"
    t.check_constraint "hostname = lower(hostname)", name: "tenant_domains_hostname_lowercase"
  end

  create_table "tenant_settings", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "tenant_id", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_tenant_settings_on_tenant_id", unique: true
    t.check_constraint "jsonb_typeof(settings) = 'object'::text", name: "tenant_settings_is_object"
  end

  create_table "tenants", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.text "name", null: false
    t.text "slug", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
    t.check_constraint "slug ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'::text", name: "tenants_slug_format"
  end

  add_foreign_key "tenant_api_keys", "tenants", on_delete: :cascade
  add_foreign_key "tenant_domains", "tenants", on_delete: :cascade
  add_foreign_key "tenant_settings", "tenants", on_delete: :cascade
end
