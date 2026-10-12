<script setup>
import { computed, ref } from "vue";
import { shop } from "../shop.js";
import { findCategory, SHOP_NAME } from "../store.js";
import ProductGrid from "../components/ProductGrid.vue";
import NotFoundPage from "./NotFoundPage.vue";

const props = defineProps({ slug: { type: String, required: true } });

const notFound = ref(false);
const category = computed(() => findCategory(props.slug));

document.title = category.value ? `${category.value.name} · ${SHOP_NAME}` : SHOP_NAME;
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
    <ProductGrid :load="(after) => shop.listCategoryProducts(slug, { after })" @not-found="notFound = true" />
  </template>
</template>
