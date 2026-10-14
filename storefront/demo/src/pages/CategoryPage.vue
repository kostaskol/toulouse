<script setup>
import { computed, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { shop } from "../shop.js";
import { findCategory, SHOP_NAME } from "../store.js";
import { filteredPath, routeFilter } from "../filters.js";
import FilterSidebar from "../components/FilterSidebar.vue";
import ProductGrid from "../components/ProductGrid.vue";
import NotFoundPage from "./NotFoundPage.vue";

const props = defineProps({ slug: { type: String, required: true } });

const router = useRouter();
const filter = routeFilter(useRoute());
const notFound = ref(false);
const facets = ref(null);
const category = computed(() => findCategory(props.slug));

document.title = category.value ? `${category.value.name} · ${SHOP_NAME}` : SHOP_NAME;

async function load(after) {
  const body = await shop.listCategoryProducts(props.slug, { after, filter });
  if (!after) facets.value = body.facets;
  return body;
}

const applyFilter = (next) => router.push(filteredPath(`/categories/${props.slug}`, next));
</script>

<template>
  <NotFoundPage v-if="notFound" />
  <template v-else>
    <h1 class="page-title">{{ category?.name }}</h1>
    <nav v-if="category?.children.length" class="chips">
      <RouterLink v-for="child in category.children" :key="child.id" :to="`/categories/${child.slug}`" class="chip">
        {{ child.name }}
      </RouterLink>
    </nav>
    <div class="filtered">
      <FilterSidebar v-if="facets" :facets="facets" :filter="filter" @change="applyFilter" />
      <div>
        <ProductGrid :load="load" @not-found="notFound = true" />
      </div>
    </div>
  </template>
</template>
