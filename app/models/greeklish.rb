# Folds a Greek word, or a Greek word typed in Latin letters, to one Latin skeleton, so that `papoutsia` and
# `παπούτσια` meet. The skeleton is lossy on purpose: letters people type interchangeably fold together.
module Greeklish
  # ου is the one pair whose letters map apart: υ alone is typed y.
  GREEK = {
    "ου" => "ou", "α" => "a", "β" => "v", "γ" => "g", "δ" => "d", "ε" => "e", "ζ" => "z", "η" => "i", "θ" => "th",
    "ι" => "i", "κ" => "k", "λ" => "l", "μ" => "m", "ν" => "n", "ξ" => "ks", "ο" => "o", "π" => "p", "ρ" => "r",
    "σ" => "s", "ς" => "s", "τ" => "t", "υ" => "y", "φ" => "f", "χ" => "ch", "ψ" => "ps", "ω" => "o"
  }.freeze
  # Letters fold before pairs, so `ahdoni` and `aidoni` meet. th, ch and nth keep their h. b is typed for β and μπ.
  LETTERS = {
    "nth" => "nth", "th" => "th", "ch" => "ch",
    "8" => "th", "3" => "ks", "x" => "ch", "h" => "i", "y" => "i", "w" => "o", "v" => "b"
  }.freeze
  PAIRS = {
    "nth" => "nth", "ou" => "u", "ai" => "e", "ei" => "i", "oi" => "i", "mp" => "b", "nt" => "d", "gk" => "g",
    "gg" => "g"
  }.freeze

  # @param word [String] Greek, or Greek typed in Latin letters
  # @return [String]
  def self.skeleton(word)
    greek = word.downcase.unicode_normalize(:nfd).delete(Sluggable::TONOS)
    voiceless = /(?=[#{Sluggable::VOICELESS}]|\P{L}|\z)/
    greek = greek.gsub(/([αεη])υ(?!#{Sluggable::DIALYTIKA})#{voiceless}/, '\1φ')
                 .gsub(/([αεη])υ(?!#{Sluggable::DIALYTIKA})/, '\1β')
    latin = greek.gsub(/\p{Mn}/, "").gsub(Regexp.union(GREEK.keys), GREEK)
    latin.gsub(Regexp.union(LETTERS.keys), LETTERS).gsub(Regexp.union(PAIRS.keys), PAIRS).squeeze
  end

  # @param word [String]
  def self.greek?(word) = word.match?(/\p{Greek}/)

  # Digits fold too, so a word needs a Latin letter before it reads as greeklish.
  #
  # @param word [String]
  def self.latin?(word) = word.match?(/\p{Latin}/)
end
