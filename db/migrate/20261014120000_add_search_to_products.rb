class AddSearchToProducts < ActiveRecord::Migration[8.1]
  def change
    enable_extension "unaccent"
    enable_extension "pg_trgm"
    # Lets the GIN indexes lead with tenant_id.
    enable_extension "btree_gin"

    reversible do |direction|
      direction.up do
        # The greek stemmer folds tonos and final sigma. unaccent catches Latin accents before it.
        execute <<~SQL
          CREATE TEXT SEARCH CONFIGURATION search (COPY = greek);
          ALTER TEXT SEARCH CONFIGURATION search ALTER MAPPING FOR word, hword, hword_part
            WITH unaccent, greek_stem;
        SQL
      end
      direction.down { execute "DROP TEXT SEARCH CONFIGURATION search" }
    end

    add_column :products, :search_document, :tsvector, null: false, default: ""
    add_column :products, :search_text, :text, null: false, default: ""
    add_index :products, [:tenant_id, :search_document], using: :gin
    add_index :products, "tenant_id, search_text gin_trgm_ops", using: :gin,
                                                             name: "index_products_on_tenant_id_and_search_text"
  end
end
