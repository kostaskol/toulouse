module Tenancy
  module AppRole
    # Rails keeps these, and the app has no reason to read or write them.
    METADATA_TABLES = %w[schema_migrations ar_internal_metadata].freeze

    class << self
      # Reads the role the primary entry connects as.
      #
      # @param env [String]
      # @return [String]
      def username(env = Rails.env)
        ActiveRecord::Base.configurations
          .configs_for(env_name: env, name: "primary", include_hidden: true)
          .configuration_hash.fetch(:username)
      end

      # Grants the app role row access to every table the running role creates,
      # now and later, and nothing that would let it own or alter one.
      #
      # @param role [String]
      # @return [String]
      def grants_sql(role = username)
        role = PG::Connection.quote_ident(role)
        metadata = METADATA_TABLES.map { |table| PG::Connection.quote_ident(table) }.join(", ")

        <<~SQL
          GRANT USAGE ON SCHEMA public TO #{role};
          GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{role};
          REVOKE ALL ON #{metadata} FROM #{role};
          ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO #{role};
        SQL
      end
    end
  end
end
