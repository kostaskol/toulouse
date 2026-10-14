<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";

const router = useRouter();
const query = ref("");

function submit() {
  const text = query.value.trim();
  // A query of dots would leave the search path, and the API finds nothing without a letter or digit.
  if (/[\p{L}\p{N}]/u.test(text)) router.push(`/search/${encodeURIComponent(text)}`);
}
</script>

<template>
  <form class="search-box" role="search" @submit.prevent="submit">
    <input v-model="query" type="search" placeholder="Αναζήτηση" aria-label="Αναζήτηση προϊόντων" />
  </form>
</template>
