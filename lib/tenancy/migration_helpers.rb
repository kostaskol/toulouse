module Tenancy
  module MigrationHelpers
    # Creates a table owned by tenants, with a uuid primary key, a not-null
    # tenant_id, its leading index and any per-tenant unique constraints.
    #
    # @param name [Symbol]
    # @param unique [Array<Symbol, Array<Symbol>>] one unique index per element,
    #   over tenant_id plus that element's columns. `[ :code, [ :kind, :size ] ]`
    #   yields unique (tenant_id, code) and unique (tenant_id, kind, size).
    # @param one_row_per_tenant [Boolean] makes the tenant_id index unique, so a
    #   tenant can own at most one row.
    # @param options [Hash] forwarded to create_table.
    # @yield [ActiveRecord::ConnectionAdapters::TableDefinition]
    def tenant_scoped_table(name, unique: [], one_row_per_tenant: false, **options)
      # uuidv7() needs Postgres 18. The schema will not load on 17.
      create_table name, id: :uuid, default: "uuidv7()", **options do |t|
        t.references :tenant, type: :uuid, null: false, index: false,
                     foreign_key: { on_delete: :cascade }
        yield t if block_given?
        t.timestamps
      end

      # The explicit add_index is what makes the index lead with tenant_id. An
      # index led by any other column cannot serve a tenant-filtered scan.
      add_index name, :tenant_id, unique: one_row_per_tenant
      Array(unique).each { |columns| add_index name, [ :tenant_id, *Array(columns) ], unique: true }
    end
  end
end
