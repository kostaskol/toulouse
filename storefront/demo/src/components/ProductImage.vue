<script setup>
import { computed } from "vue";

const props = defineProps({ product: { type: Object, required: true } });

// Products have no images yet, so each gets a steady colour from its slug.
const hue = computed(() => [...props.product.slug].reduce((sum, char) => (sum * 31 + char.charCodeAt(0)) % 360, 0));
</script>

<template>
  <div class="product-image" :style="{ '--hue': hue }" role="img" :aria-label="product.title">
    <span>{{ product.title[0] }}</span>
  </div>
</template>
