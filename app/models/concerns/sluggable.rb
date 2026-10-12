# A per-tenant URL slug, generated once from the record's name and changed only
# when the merchant sends a new one.
module Sluggable
  extend ActiveSupport::Concern

  FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  # ELOT 743. Pairs come before single letters, so they win.
  PAIRS = {
    "ου" => "ou", "γγ" => "ng", "γκ" => "gk", "γξ" => "nx", "γχ" => "nch", "ντ" => "nt", "μπ" => "mp"
  }.freeze
  LETTERS = {
    "α" => "a", "β" => "v", "γ" => "g", "δ" => "d", "ε" => "e", "ζ" => "z", "η" => "i", "θ" => "th",
    "ι" => "i", "κ" => "k", "λ" => "l", "μ" => "m", "ν" => "n", "ξ" => "x", "ο" => "o", "π" => "p",
    "ρ" => "r", "σ" => "s", "ς" => "s", "τ" => "t", "υ" => "y", "φ" => "f", "χ" => "ch", "ψ" => "ps",
    "ω" => "o"
  }.freeze
  TONOS = "́"
  DIALYTIKA = "̈"
  # αυ, ευ and ηυ read as f before these and at the end of a word, and as v elsewhere.
  VOICELESS = "θκξπστφχψς"

  included do
    before_validation :generate_slug, on: :create

    # A blank name already reports its own error.
    validates :slug, presence: { if: -> { slug_source.present? } }, format: { with: FORMAT, allow_blank: true },
                     uniqueness: { scope: :tenant_id }
  end

  # @param text [String]
  # @return [String]
  def self.transliterate(text)
    # Decomposed, so the tonos drops and a dialytika still blocks a pair.
    greek = text.downcase.unicode_normalize(:nfd).delete(TONOS)
    greek = greek.gsub(/([αεη])υ(?!#{DIALYTIKA})(?=[#{VOICELESS}]|\P{L}|\z)/) { "#{LETTERS[$1]}f" }
                 .gsub(/([αεη])υ(?!#{DIALYTIKA})/) { "#{LETTERS[$1]}v" }
                 .gsub(/(?<!\p{L})μπ|μπ(?!\p{L})/, "b")
                 .gsub(Regexp.union(PAIRS.keys), PAIRS)
                 .delete(DIALYTIKA)
                 .gsub(Regexp.union(LETTERS.keys), LETTERS)

    # parameterize keeps underscores, which the slug format refuses.
    greek.tr("_", " ").parameterize
  end

  private

  # Products often share a title, so a taken slug gets the first free number.
  def generate_slug
    return if slug.present?

    base = Sluggable.transliterate(slug_source.to_s)
    self.slug = base
    number = 1
    self.slug = "#{base}-#{number += 1}" while base.present? && self.class.exists?(slug:)
  end
end
