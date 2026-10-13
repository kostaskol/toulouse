<script setup>
import { formatPrice } from "../format.js";

defineProps({
  price: { type: Number, required: true },
  preDiscount: { type: Number, default: null },
  from: { type: Boolean, default: false }
});
</script>

<template>
  <span class="price">
    <span v-if="from" class="price-from">από </span>
    <span :class="{ 'price-sale': preDiscount }">{{ formatPrice(price) }}</span>
    <s v-if="preDiscount" class="price-compare">{{ formatPrice(preDiscount) }}</s>
  </span>
</template>
