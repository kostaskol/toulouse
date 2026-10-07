class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Platform admin runs its requests as its own database role.
  connects_to database: { writing: :primary, platform: :platform }
end
