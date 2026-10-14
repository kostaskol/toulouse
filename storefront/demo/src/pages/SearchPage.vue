<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { shop } from "../shop.js";
import { SHOP_NAME } from "../store.js";
import { filteredPath, routeFilter } from "../filters.js";
import FilterSidebar from "../components/FilterSidebar.vue";
import ProductGrid from "../components/ProductGrid.vue";

const props = defineProps({ query: { type: String, required: true } });

const router = useRouter();
const filter = routeFilter(useRoute());
const fuzzy = ref(false);
const facets = ref(null);

document.title = `${props.query} · ${SHOP_NAME}`;

async function load(after) {
  const body = await shop.search(props.query, { after, filter });
  if (body.category) {
    router.replace(`/categories/${body.category.slug}`);
    return { products: [], meta: { next_cursor: null } };
  }

  if (!after) {
    fuzzy.value = body.meta.match === "fuzzy" && body.products.length > 0;
    facets.value = body.facets;
  }
  return body;
}

const applyFilter = (next) => router.push(filteredPath(`/search/${encodeURIComponent(props.query)}`, next));
</script>

<template>
  <h1 class="page-title">Αναζήτηση: {{ query }}</h1>
  <p v-if="fuzzy" class="muted">Δεν βρήκαμε ακριβώς αυτό. Δείτε παρόμοια προϊόντα.</p>
  <div class="filtered">
    <FilterSidebar v-if="facets" :facets="facets" :filter="filter" @change="applyFilter" />
    <div>
      <ProductGrid :load="load" empty="Δεν βρήκαμε προϊόντα για αυτή την αναζήτηση." />
    </div>
  </div>
</template>
