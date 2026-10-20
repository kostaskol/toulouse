# A shopper's cart, or a guest's, which is found by the digest of an opaque
# token. Holds no stock: each line's state is read from the variant.
class Cart < ApplicationRecord
  include Tenancy::Scoped

  # Distinct from every other token type, so a surface can reject another
  # token without a query.
  TOKEN_PREFIX = "tca_".freeze
  # A guest cart lasts as long as an idle shopper session.
  GUEST_IDLE_TIMEOUT = Shopper::Session::IDLE_TIMEOUT

  # Readable only on the instance that created it. Nothing recovers it later.
  attr_reader :token

  belongs_to :shopper, optional: true
  has_many :lines, -> { order(:id) }, inverse_of: :cart

  scope :expired, -> { where(expires_at: ..Time.current) }

  before_create :assign_token, if: :guest?

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token)

  # Row-level security hides another tenant's cart, so it answers like an
  # unknown one.
  #
  # @param token [String, nil]
  # @return [Cart, nil] the live guest cart the token opens
  def self.for_guest(token)
    # Compared as raw bytes, so a header with malformed UTF-8 cannot raise.
    token = token&.b
    return unless token&.start_with?(TOKEN_PREFIX)

    find_by(token_digest: digest(token), expires_at: Time.current..)
  end

  # Moves the guest cart's lines into the shopper's cart. A variant in both
  # sums, past the stock left, because signing in must not fail on stock.
  #
  # @param token [String, nil]
  # @param shopper [Shopper]
  # @return [Boolean] whether both carts held lines
  def self.merge_guest!(token, shopper)
    transaction do
      # Locked, so a second sign-in with the same token waits and then finds no cart to add twice.
      guest = lock.for_guest(token)
      next false if guest.nil?

      cart = create_or_find_by!(shopper:)
      cart.with_lock do
        both = guest.lines.any? && cart.lines.any?
        guest.lines.each { |line| cart.lines.find_or_initialize_by(variant_id: line.variant_id).add(line.quantity) }
        guest.destroy!
        both
      end
    end
  end

  def guest? = shopper_id.nil?

  # Adds to the variant's line, up to the stock left.
  #
  # @param variant [Product::Variant] one the caller found sellable
  # @param quantity [Integer]
  # @return [Boolean] whether the stock left cut the quantity
  def add!(variant, quantity)
    changing do
      line = lines.find_or_initialize_by(variant:)
      clamp(line, variant, line.quantity.to_i + quantity)
    end
  end

  # Sets the quantity of a line already in the cart, up to the stock left.
  #
  # @param variant [Product::Variant] one the caller found sellable
  # @param quantity [Integer]
  # @return [Boolean] whether the stock left cut the quantity
  def set!(variant, quantity)
    changing { clamp(lines.find_by!(variant:), variant, quantity) }
  end

  # @param variant_id [String]
  def remove!(variant_id)
    changing { lines.find_by!(variant_id:).destroy! }
  end

  private

  def assign_token
    @token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
    self.token_digest = self.class.digest(@token)
    self.expires_at = GUEST_IDLE_TIMEOUT.from_now
  end

  # Limits by the variant the caller checked, so a sale since then cannot clamp the line to zero.
  def clamp(line, variant, wanted)
    line.variant = variant
    line.update!(quantity: [wanted, line.quantity_limit].min)
    line.quantity < wanted
  end

  # Locks the cart, so two writes to one line both count, and moves a guest
  # cart's expiry.
  def changing(&)
    with_lock do
      update_columns(expires_at: GUEST_IDLE_TIMEOUT.from_now) if guest?
      yield
    end
  end
end
