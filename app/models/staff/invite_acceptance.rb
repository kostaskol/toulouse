# Lets an invited member set their password through the emailed link, links
# their storefront shopper, and signs them in.
class Staff::InviteAcceptance
  Result = Data.define(:session, :shopper_merged, :failure) do
    def self.success(session, shopper_merged:) = new(session:, shopper_merged:, failure: nil)
    def self.failure(reason) = new(session: nil, shopper_merged: false, failure: reason)
  end

  # @param slug [String, nil]
  # @param token [String, nil]
  # @param password [String, nil]
  # @return [Staff::InviteAcceptance::Result]
  def self.call(slug:, token:, password:)
    new(slug.to_s, token.to_s, password.to_s).call
  end

  def initialize(slug, token, password)
    @slug = slug
    @token = token
    @password = password
  end

  def call
    tenant = Tenant.find_by(slug: @slug)
    return refuse(:unknown_slug) if tenant.nil?

    Tenancy.with_tenant(tenant) { accept(tenant) }
  end

  private

  def accept(tenant)
    staff = Staff.find_by_token_for(:invite, @token)
    return refuse(staff ? :not_pending : :bad_token) unless staff&.pending?
    # Checked after the token, so only someone holding a valid link learns the status.
    return Result.failure(:tenant_suspended) if tenant.suspended?

    # A blank password leaves the digest as it was rather than failing validation.
    staff.password = @password
    staff.status = :active
    return Result.failure(:invalid_password) if @password.empty? || !staff.valid?

    Staff.transaction do
      staff.save!
      shopper_merged = link_shopper(staff)
      LoginAttempt.clear(staff.email)
      Result.success(staff.sessions.create!, shopper_merged:)
    end
  end

  # The token proves the member controls the inbox, which is what makes taking
  # over a shopper with the same email safe.
  def link_shopper(staff)
    shopper = Shopper.find_by(email: staff.email)

    if shopper.nil?
      Shopper.create!(email: staff.email, staff:)
      return false
    end

    # Without the argument, an association's delete_all nulls the foreign key.
    shopper.sessions.delete_all(:delete_all)
    shopper.update!(staff:, password_digest: nil)
    true
  end

  # Refusals answer alike, so this log is the only place the reason survives.
  def refuse(reason)
    Rails.logger.warn { "Staff invite acceptance refused: #{reason} slug=#{@slug}" }
    Result.failure(:invalid_token)
  end
end
