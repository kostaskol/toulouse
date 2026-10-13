<script setup>
import { computed } from "vue";
import ProductImage from "./ProductImage.vue";
import ProductPrice from "./ProductPrice.vue";

const props = defineProps({ product: { type: Object, required: true } });

const cheapest = computed(() => props.product.variants.reduce((low, variant) =>
  variant.price_cents < low.price_cents ? variant : low));
const priceVaries = computed(() =>
  props.product.variants.some((variant) => variant.price_cents !== cheapest.value.price_cents));
const soldOut = computed(() => props.product.variants.every((variant) => !variant.available));
</script>

<template>
  <RouterLink :to="`/products/${product.slug}`" class="product-card">
    <ProductImage :product="product" />
    <span v-if="soldOut" class="badge">Εξαντλήθηκε</span>
    <span v-else-if="cheapest.pre_discount_price_cents" class="badge badge-sale">Προσφορά</span>
    <span class="product-card-brand">{{ product.brand?.name }}</span>
    <span class="product-card-title">{{ product.title }}</span>
    <ProductPrice :price="cheapest.price_cents" :pre-discount="cheapest.pre_discount_price_cents" :from="priceVaries" />
  </RouterLink>
</template>
