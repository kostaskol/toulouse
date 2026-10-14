<script setup>
import { ref } from "vue";
import ProductCard from "./ProductCard.vue";
import { errorMessage } from "../messages.js";

// Resolves to the API's list body for the page after the given cursor.
const props = defineProps({
  load: { type: Function, required: true },
  empty: { type: String, default: "Δεν υπάρχουν προϊόντα εδώ ακόμα." }
});
const emit = defineEmits(["not-found"]);

const products = ref([]);
const nextCursor = ref(null);
const loading = ref(false);
const loaded = ref(false);
const error = ref(null);

async function loadPage(after) {
  loading.value = true;
  error.value = null;
  try {
    const { products: page, meta } = await props.load(after);
    products.value = after ? [...products.value, ...page] : page;
    nextCursor.value = meta.next_cursor;
    loaded.value = true;
  } catch (failure) {
    if (failure.code === "invalid_cursor") return await loadPage(null);
    if (failure.code === "not_found") return emit("not-found");
    error.value = errorMessage(failure);
  } finally {
    loading.value = false;
  }
}

loadPage(null);
</script>

<template>
  <p v-if="error" class="form-error">{{ error }}</p>
  <p v-else-if="loaded && !products.length" class="muted">{{ empty }}</p>
  <div class="product-grid">
    <ProductCard v-for="product in products" :key="product.id" :product="product" />
  </div>
  <div v-if="nextCursor" class="load-more">
    <button class="button button-outline" :disabled="loading" @click="loadPage(nextCursor)">
      Περισσότερα προϊόντα
    </button>
  </div>
</template>
