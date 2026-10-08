# Invites a member into the current tenant, or sends a pending member a new
# link.
class Staff::Invite
  Result = Data.define(:staff, :created, :failure) do
    def self.success(staff, created:) = new(staff:, created:, failure: nil)
    def self.failure(reason) = new(staff: nil, created: false, failure: reason)
  end

  # @param email [String, nil]
  # @return [Staff::Invite::Result]
  def self.call(email:)
    new(email.to_s).call
  end

  def initialize(email)
    @email = email
  end

  def call
    staff = Staff.find_or_initialize_by(email: @email)
    return Result.failure(:email_taken) if staff.active?

    created = staff.new_record?
    staff.invited_at = Time.current
    return Result.failure(:invalid_email) unless staff.save

    StaffMailer.invite(staff).deliver_later
    Result.success(staff, created:)
  end
end
