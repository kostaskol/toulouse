<script setup>
import { computed, onMounted, onUnmounted, reactive, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useAction } from "../action.js";
import { flatten, loadCategories } from "../categories.js";
import { PRODUCT_STATUS_BADGES, PRODUCT_STATUSES } from "../labels.js";
import { getAll, useList } from "../list.js";
import { baseErrors } from "../messages.js";
import { priceRange, stockTotal, thumbnail } from "../products.js";
import FormErrors from "../components/FormErrors.vue";
import LoadMore from "../components/LoadMore.vue";

// The API refuses shorter queries.
const MIN_QUERY = 2;

const route = useRoute();
const router = useRouter();
const filters = reactive({
  q: route.query.q ?? "", status: route.query.status ?? "", brand_id: route.query.brand_id ?? "",
  category_id: route.query.category_id ?? ""
});
const options = reactive({ brands: [], categories: [] });
const loadingOptions = useAction();
const list = useList("/products", "products", () => ({
  ...filters, q: filters.q.trim().length >= MIN_QUERY ? filters.q.trim() : undefined
}));
const errors = computed(() => baseErrors(list.error.value, loadingOptions.error.value));

let typing;

onMounted(() => {
  list.load();
  loadingOptions.run(async () => {
    [options.brands, options.categories] = await Promise.all([getAll("/brands", "brands"), loadCategories()]);
  });
});

onUnmounted(() => clearTimeout(typing));

watch(() => [filters.status, filters.brand_id, filters.category_id], reload);
watch(() => filters.q, () => {
  clearTimeout(typing);
  typing = setTimeout(reload, 300);
});

function reload() {
  router.replace({ query: Object.fromEntries(Object.entries(filters).filter(([, value]) => value)) });
  list.load();
}
</script>

<template>
  <div class="page-head">
    <h1>Προϊόντα</h1>
    <RouterLink to="/products/new" class="button button-primary">Νέο προϊόν</RouterLink>
  </div>

  <div class="filters">
    <input v-model="filters.q" class="search" type="search" placeholder="Αναζήτηση με τίτλο, SKU, μάρκα…">
    <select v-model="filters.status">
      <option value="">Όλες οι καταστάσεις</option>
      <option v-for="(label, status) in PRODUCT_STATUSES" :key="status" :value="status">{{ label }}</option>
    </select>
    <select v-model="filters.brand_id">
      <option value="">Όλες οι μάρκες</option>
      <option v-for="brand in options.brands" :key="brand.id" :value="brand.id">{{ brand.name }}</option>
    </select>
    <select v-model="filters.category_id">
      <option value="">Όλες οι κατηγορίες</option>
      <option v-for="category in flatten(options.categories)" :key="category.id" :value="category.id">
        {{ category.label }}
      </option>
    </select>
  </div>

  <FormErrors :messages="errors" />
  <div class="table-wrap">
    <table>
      <thead>
        <tr>
          <th></th><th>Τίτλος</th><th>Κατάσταση</th><th>Μάρκα</th>
          <th class="num">Παραλλαγές</th><th class="num">Τιμή</th><th class="num">Απόθεμα</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="product in list.items.value" :key="product.id">
          <td style="width: 56px">
            <img v-if="thumbnail(product)" :src="thumbnail(product)" alt="" class="thumb">
            <span v-else class="thumb"></span>
          </td>
          <td><RouterLink :to="`/products/${product.id}`">{{ product.title }}</RouterLink></td>
          <td>
            <span class="badge" :class="PRODUCT_STATUS_BADGES[product.status]">
              {{ PRODUCT_STATUSES[product.status] }}
            </span>
          </td>
          <td>{{ product.brand?.name }}</td>
          <td class="num">{{ product.variants.length }}</td>
          <td class="num nowrap">{{ priceRange(product) }}</td>
          <td class="num">{{ stockTotal(product) ?? "—" }}</td>
        </tr>
        <tr v-if="!list.busy.value && !list.items.value.length">
          <td colspan="7" class="empty">Δεν βρέθηκαν προϊόντα.</td>
        </tr>
      </tbody>
    </table>
  </div>
  <LoadMore :next="list.next.value" :busy="list.busy.value" @more="list.loadMore" />
</template>
