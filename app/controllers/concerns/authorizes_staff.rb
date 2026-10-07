module AuthorizesStaff
  extend ActiveSupport::Concern

  ANY_STAFF = :any_staff

  class UndeclaredAction < StandardError; end

  FAILURES = {
    permission_denied: RendersFailures::Failure.new(
      status: :forbidden,
      code: "permission_denied",
      message: "Your role does not allow this action."
    )
  }.freeze

  included do
    class_attribute :staff_authorization_default, instance_accessor: false
    class_attribute :staff_authorizations, instance_accessor: false, default: {}.freeze

    before_action :authorize_staff!
  end

  class_methods do
    # Requires a permission for the given actions, or for every action.
    #
    # @param permission [Symbol]
    # @param only [Symbol, Array<Symbol>, nil]
    def requires_permission(permission, only: nil)
      raise ArgumentError, "No role has the permission #{permission.inspect}" unless Staff.permission?(permission)

      declare_staff_authorization(permission, only)
    end

    # Opens the given actions, or every action, to any signed-in staff member.
    #
    # @param only [Symbol, Array<Symbol>, nil]
    def allow_any_staff(only: nil)
      declare_staff_authorization(ANY_STAFF, only)
    end

    # @param action [Symbol, String]
    # @return [Symbol, nil] a permission, ANY_STAFF, or nil when the action declares nothing
    def staff_authorization(action)
      staff_authorizations.fetch(action.to_s, staff_authorization_default)
    end

    private

    def declare_staff_authorization(requirement, only)
      if only.nil?
        self.staff_authorization_default = requirement
      else
        self.staff_authorizations = staff_authorizations.merge(Array(only).to_h { |action| [action.to_s, requirement] })
      end
    end
  end

  private

  def authorize_staff!
    requirement = self.class.staff_authorization(action_name)
    raise UndeclaredAction, "#{self.class.name}##{action_name} declares no staff authorization" if requirement.nil?
    return if requirement == ANY_STAFF || Current.user.can?(requirement)

    render_failure(FAILURES.fetch(:permission_denied))
  end
end
