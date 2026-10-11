module Tenancy
  module IsolationCheck
    class << self
      # Lists every way the app or platform role could see past row-level
      # security. Empty when both are isolated.
      #
      # @param app [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter]
      # @param platform [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter]
      # @return [Array<String>]
      def failures(app, platform)
        failures = role_failures(app) + role_failures(platform)
        failures << "the app role can reach the platform schema" if app.select_value(
          "SELECT has_schema_privilege('platform', 'USAGE')"
        )
        failures += unprotected_tables(app).map { |table| "#{table} has no tenant isolation policy" }
        failures + row_counts(app).filter_map { |table, count| "the app role sees #{count} #{table} rows" if count.positive? }
      end

      # Each of these lets the connected role skip row-level security. Owning a
      # table lets it switch the policy off.
      #
      # @param connection [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter]
      # @return [Array<String>]
      def role_failures(connection)
        role = connection.select_one(<<~SQL)
          SELECT current_user AS name, rolsuper, rolbypassrls,
            EXISTS (SELECT FROM pg_class WHERE relowner = pg_roles.oid) AS owns
          FROM pg_roles WHERE rolname = current_user
        SQL

        { "rolsuper" => "is superuser", "rolbypassrls" => "has BYPASSRLS", "owns" => "owns relations" }
          .filter_map { |column, failure| "#{role['name']} #{failure}" if role[column] }
      end

      # pg_catalog rather than information_schema, which hides tables the role
      # holds no privilege on.
      #
      # @param connection [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter]
      # @return [Array<String>]
      def tenant_tables(connection)
        connection.select_values(<<~SQL)
          SELECT c.relname FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          JOIN pg_attribute a ON a.attrelid = c.oid
          WHERE n.nspname = 'public' AND c.relkind = 'r'
            AND a.attname = 'tenant_id' AND NOT a.attisdropped
        SQL
      end

      # @param connection [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter]
      # @return [Array<String>]
      def unprotected_tables(connection)
        protected_tables = connection.select_values(<<~SQL)
          SELECT c.relname FROM pg_class c
          JOIN pg_policies p ON p.tablename = c.relname AND p.schemaname = 'public'
          WHERE c.relrowsecurity AND p.policyname = 'tenant_isolation'
        SQL

        tenant_tables(connection) - protected_tables
      end

      # Counts what the connected role sees in each tenant table under its
      # current settings.
      #
      # @param connection [ActiveRecord::ConnectionAdapters::PostgreSQLAdapter]
      # @return [Hash{String => Integer}]
      def row_counts(connection)
        tenant_tables(connection).index_with do |table|
          connection.select_value("SELECT count(*) FROM #{connection.quote_table_name(table)}")
        end
      end
    end
  end
end
