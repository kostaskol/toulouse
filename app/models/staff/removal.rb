# Cancels a pending member's invite, or removes an active member from the
# current tenant.
class Staff::Removal
  # @param staff [Staff]
  # @return [Symbol, nil] why the member was not removed
  def self.call(staff)
    new(staff).call
  end

  def initialize(staff)
    @staff = staff
  end

  def call
    Staff.transaction do
      # Locked, so two owners removing each other cannot both pass the check.
      # Owners first, in id order, so two removals never wait on each other.
      owners = Staff.active.owner.order(:id).lock.pluck(:id)
      # Locked, so an invite acceptance cannot undo the removal.
      @staff.lock!
      return :last_owner if owners == [@staff.id]

      remove
      nil
    end
  end

  private

  # The row stays, even for a cancelled invite, so a re-invite reuses it and
  # records it authored keep their link. The shopper stays as the person's own
  # account, signed in with the password they already used on the storefront.
  def remove
    @staff.end_sessions
    @staff.shopper&.update!(staff: nil, password_digest: @staff.password_digest)
    @staff.update!(status: :removed, password_digest: nil)
  end
end
