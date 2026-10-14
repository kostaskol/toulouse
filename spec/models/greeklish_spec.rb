require "rails_helper"

RSpec.describe Greeklish do
  # The fold table of the search batch spec: each Greek spelling and the ways it is typed.
  {
    "ου" => ["ou", "u"],
    "αι" => ["ai", "e"],
    "ει" => ["ei", "i"], "οι" => ["oi", "i"], "υι" => ["yi", "i"], "η" => ["h", "i"], "ι" => ["i"], "υ" => ["y", "i"],
    "ω" => ["w", "o"], "ο" => ["o"],
    "θ" => ["th", "8"],
    "χ" => ["ch", "x"],
    "ξ" => ["ks", "3"],
    "ψ" => ["ps"],
    "μπ" => ["mp", "b"],
    "ντ" => ["nt", "d"],
    "γκ" => ["gk", "gg", "g"], "γγ" => ["gk", "gg", "g"],
    "β" => ["v", "b"]
  }.each do |greek, typed|
    typed.each do |latin|
      it "folds #{latin} like #{greek}" do
        expect(described_class.skeleton("λ#{latin}λ")).to eq(described_class.skeleton("λ#{greek}λ"))
      end
    end
  end

  it "folds a Greek word and its greeklish spelling together" do
    expect(described_class.skeleton("Παπούτσια")).to eq(described_class.skeleton("papoutsia"))
  end

  it "folds letters before pairs" do
    expect(described_class.skeleton("ahdoni")).to eq(described_class.skeleton("αηδόνι"))
  end

  it "keeps the h of th and ch" do
    expect(described_class.skeleton("θ")).not_to eq(described_class.skeleton("τι"))
    expect(described_class.skeleton("χ")).not_to eq(described_class.skeleton("κι"))
  end

  it "reads αυ as af before a voiceless letter and av elsewhere" do
    expect(described_class.skeleton("αυτ")).to eq(described_class.skeleton("aft"))
    expect(described_class.skeleton("αυα")).to eq(described_class.skeleton("ava"))
  end

  it "keeps αϋ as two vowels" do
    expect(described_class.skeleton("αϋ")).to eq(described_class.skeleton("ai"))
  end

  it "folds a doubled letter to one" do
    expect(described_class.skeleton("αλλα")).to eq(described_class.skeleton("ala"))
  end
end
