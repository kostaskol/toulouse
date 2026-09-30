# Migrations run as the owner. The app role can neither create tables nor read
# past row-level security, so specs about the schema itself connect as this.
class SchemaOwnerRecord < ActiveRecord::Base
  self.abstract_class = true

  establish_connection configurations.configs_for(env_name: Rails.env, name: "owner")
end
