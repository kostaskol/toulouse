module Tenancy
  module MigrationHelpers
    # A connection that once held a tenant reads back '' rather than null after
    # a reset, and ''::uuid raises.
    CURRENT_TENANT_SQL = "NULLIF(current_setting('app.tenant_id', true), '')::uuid".freeze

    # Creates a table owned by tenants, with a uuid primary key, a not-null
    # tenant_id, its leading index, any per-tenant unique constraints and its
    # row-level security policy.
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

      enable_tenant_isolation name
    end

    # Limits the app role to rows of the tenant set on its connection. Enabled
    # rather than forced, so the owner running migrations still sees every row.
    #
    # @param table [Symbol]
    def enable_tenant_isolation(table)
      table = quote_table_name(table)

      reversible do |direction|
        direction.up do
          execute <<~SQL
            ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
            CREATE POLICY tenant_isolation ON #{table}
              USING (tenant_id = #{CURRENT_TENANT_SQL})
              WITH CHECK (tenant_id = #{CURRENT_TENANT_SQL});
          SQL
        end

        direction.down do
          execute <<~SQL
            DROP POLICY tenant_isolation ON #{table};
            ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY;
          SQL
        end
      end
    end
  end
end
