<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { shop } from "../shop.js";
import { SHOP_NAME } from "../store.js";
import ProductGrid from "../components/ProductGrid.vue";

const props = defineProps({ query: { type: String, required: true } });

const router = useRouter();
const fuzzy = ref(false);

document.title = `${props.query} · ${SHOP_NAME}`;

async function load(after) {
  const body = await shop.search(props.query, { after });
  if (body.category) {
    router.replace(`/categories/${body.category.slug}`);
    return { products: [], meta: { next_cursor: null } };
  }

  if (!after) fuzzy.value = body.meta.match === "fuzzy" && body.products.length > 0;
  return body;
}
</script>

<template>
  <h1 class="page-title">Αναζήτηση: {{ query }}</h1>
  <p v-if="fuzzy" class="muted">Δεν βρήκαμε ακριβώς αυτό. Δείτε παρόμοια προϊόντα.</p>
  <ProductGrid :load="load" empty="Δεν βρήκαμε προϊόντα για αυτή την αναζήτηση." />
</template>
