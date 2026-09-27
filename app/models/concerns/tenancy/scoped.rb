module Tenancy
  module Scoped
    extend ActiveSupport::Concern

    included do
      belongs_to :tenant
    end
  end
end
