<script setup>
import { SHOP_NAME } from "../store.js";

document.title = `Δεν βρέθηκε · ${SHOP_NAME}`;
</script>

<template>
  <section class="empty-state">
    <h1>Η σελίδα δεν βρέθηκε</h1>
    <p>Ίσως το προϊόν να μην είναι πια διαθέσιμο.</p>
    <RouterLink to="/" class="button">Πίσω στο κατάστημα</RouterLink>
  </section>
</template>
