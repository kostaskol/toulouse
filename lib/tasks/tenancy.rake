# pg_dump runs with --no-privileges, so a database loaded from structure.sql
# gets the app role's grants only if they are written into the file. Anonymous,
# because opening Tenancy here would stop Zeitwerk loading app/models/tenancy.rb.
ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(Module.new do
  def structure_dump(configuration, *arguments)
    super
    File.open(arguments.first, "a") do |file|
      file.puts("", Tenancy::AppRole.grants_sql(Tenancy::AppRole.username(configuration.env_name)))
      file.puts("", Platform::DatabaseRole.grants_sql(Platform::DatabaseRole.username(configuration.env_name)))
    end
  end
end)

# Tasks that act on one database, such as db:rollback, use ActiveRecord::Base's
# pool, which is the app role. Schema work needs the owner. Through
# ApplicationRecord, whose connects_to would otherwise put the app role back
# when it first loads.
Rake::Task["db:load_config"].enhance do
  owner = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "owner")
  ApplicationRecord.establish_connection(owner) if owner
end
