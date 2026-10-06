module Tenancy
  # Checked before every query rather than hooked to Current, because
  # Current.reset skips the setters and a rolled-back SET is undone.
  module ConnectionSettings
    # In an aborted transaction Postgres accepts only these, and Current may have
    # changed between the error and the rollback.
    TRANSACTION_CONTROL = /\A\s*(BEGIN|COMMIT|END|ROLLBACK|SAVEPOINT|RELEASE)\b/i
    ROLLBACK = /\A\s*ROLLBACK\b/i

    SYNC_SQL = <<~SQL.squish.freeze
      SELECT set_config('app.tenant_id', $1, false), set_config('app.api_key_digest', $2, false),
             set_config('app.staff_session_digest', $3, false)
    SQL

    # A new or reset session has none of the settings, which the policies read
    # the same as an empty string.
    UNSET = [ "", "", "" ].freeze

    # A query cache hit never reaches perform_query, and the cache keys on SQL
    # alone, so a result cached as one tenant could answer for another.
    def select_all(...)
      clear_query_cache if query_cache_enabled && @tenancy_settings != wanted_tenancy_settings
      super
    end

    private

    def perform_query(raw_connection, sql, *, **)
      if sql.match?(TRANSACTION_CONTROL)
        @tenancy_settings = nil if sql.match?(ROLLBACK)
      else
        sync_tenancy_settings(raw_connection)
      end

      super
    end

    def configure_connection
      @tenancy_settings = UNSET
      super
    end

    def wanted_tenancy_settings
      [ Current.tenant_id.to_s, Current.api_key_digest.to_s, Current.staff_session_digest.to_s ]
    end

    def sync_tenancy_settings(raw_connection)
      wanted = wanted_tenancy_settings
      return if @tenancy_settings == wanted

      raw_connection.exec_params(SYNC_SQL, wanted).clear
      @tenancy_settings = wanted
    end
  end
end
