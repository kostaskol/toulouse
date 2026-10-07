# Platform admin: our own surface, across tenants.
module Platform
  # A schema the app role has no usage on.
  def self.table_name_prefix = "platform."
end
