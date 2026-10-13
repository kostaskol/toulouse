<script setup>
import { formatPrice } from "../format.js";

defineProps({
  price: { type: Number, required: true },
  compareAt: { type: Number, default: null },
  from: { type: Boolean, default: false }
});
</script>

<template>
  <span class="price">
    <span v-if="from" class="price-from">από </span>
    <span :class="{ 'price-sale': compareAt }">{{ formatPrice(price) }}</span>
    <s v-if="compareAt" class="price-compare">{{ formatPrice(compareAt) }}</s>
  </span>
</template>
