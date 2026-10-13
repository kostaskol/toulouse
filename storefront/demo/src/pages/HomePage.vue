<script setup>
import { shop } from "../shop.js";
import { SHOP_NAME } from "../store.js";
import ProductGrid from "../components/ProductGrid.vue";

document.title = SHOP_NAME;
</script>

<template>
  <section class="hero">
    <h1>Καλοκαίρι από λινό</h1>
    <p>Ρούχα που αναπνέουν, φτιαγμένα για τη ζέστη και τη θάλασσα.</p>
  </section>
  <h2 class="section-title">Νέες αφίξεις</h2>
  <ProductGrid :load="(after) => shop.listProducts({ after })" />
</template>
