require "rails_helper"

RSpec.describe Sluggable do
  describe ".transliterate" do
    {
      "Πουκάμισο Λευκό" => "poukamiso-lefko",
      "Πουκάμισο_Λευκό" => "poukamiso-lefko",
      "Αυγό" => "avgo",
      "Ευτυχία" => "eftychia",
      "μπάλα" => "bala",
      "Λάμπα" => "lampa",
      "Άγγελος" => "angelos",
      "ΣΚΟΥΦΟΣ" => "skoufos",
      "Πραΰνω" => "prayno"
    }.each do |text, slug|
      it "turns #{text} into #{slug}" do
        expect(described_class.transliterate(text)).to eq(slug)
      end
    end
  end

  describe "on a record", :as_tenant do
    it "is generated from the name on create" do
      expect(create(:brand, name: "Πουκάμισο Λευκό").slug).to eq("poukamiso-lefko")
    end

    it "takes the first free number when the generated slug is taken" do
      name = "Πουκάμισο Λευκό"
      create(:brand, slug: "poukamiso-lefko")
      create(:brand, slug: "poukamiso-lefko-2")

      expect(create(:brand, name:).slug).to eq("poukamiso-lefko-3")
    end

    it "keeps a slug the merchant sends" do
      slug = build(:brand).name.parameterize

      expect(create(:brand, name: "Πουκάμισο", slug:).slug).to eq(slug)
    end

    it "stays when the name changes" do
      brand = create(:brand)

      expect { brand.update!(name: build(:brand).name) }.not_to change(brand, :slug)
    end

    it "must be lowercase words joined by hyphens" do
      expect(build(:brand, slug: "Not A Slug")).not_to be_valid
    end
  end
end
