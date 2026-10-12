class Version < ApplicationRecord
  include PaperTrail::VersionConcern
  include Tenancy::Scoped
end
