module Platform
  module DatabaseRole
    class << self
      # Reads the role the platform entry connects as.
      #
      # @param env [String]
      # @return [String]
      def username(env = Rails.env)
        ActiveRecord::Base.configurations
          .configs_for(env_name: env, name: "platform", include_hidden: true)
          .configuration_hash.fetch(:username)
      end

      # Grants the platform role the app role's row access to tenant tables,
      # which row-level security still limits, and the platform schema, which no
      # other role reaches.
      #
      # @param role [String]
      # @return [String]
      def grants_sql(role = username)
        quoted = PG::Connection.quote_ident(role)

        <<~SQL
          #{Tenancy::AppRole.grants_sql(role).strip}
          GRANT USAGE ON SCHEMA platform TO #{quoted};
          GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA platform TO #{quoted};
          ALTER DEFAULT PRIVILEGES IN SCHEMA platform GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO #{quoted};
        SQL
      end
    end
  end
end
