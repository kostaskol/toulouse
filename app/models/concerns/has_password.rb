# The password rules for every account that signs in with one. Rails' own
# validations are off, because pending staff and linked shoppers have no
# password.
module HasPassword
  extend ActiveSupport::Concern

  included do
    has_secure_password validations: false

    validates :password, confirmation: { allow_nil: true },
                         length: { minimum: ->(record) { record.class::MINIMUM_PASSWORD_LENGTH }, allow_nil: true }
    validate :password_not_blank
    validate :password_fits_bcrypt

    # Defined on the class, so it runs before the setter has_secure_password adds.
    # That setter ignores an empty password, which would let a reset keep the old one.
    def password=(password)
      @blank_password = !password.nil? && password.blank?
      super
    end
  end

  private

  def password_not_blank
    errors.add(:password, :blank) if @blank_password
  end

  def password_fits_bcrypt
    return unless password.present? && password.bytesize > ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED

    errors.add(:password, :password_too_long)
  end
end
