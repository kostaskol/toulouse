module QueryCounter
  IGNORED_NAMES = ["SCHEMA", "TRANSACTION"].freeze
  IGNORED_SQL = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i

  def count_queries
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if IGNORED_NAMES.include?(payload[:name])
      next if IGNORED_SQL.match?(payload[:sql])

      count += 1
    end

    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
