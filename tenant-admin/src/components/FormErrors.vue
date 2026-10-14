<script setup>
defineProps({ messages: { type: Array, default: () => [] } });
</script>

<template>
  <div v-for="message in messages" :key="message" class="alert alert-error" role="alert">{{ message }}</div>
</template>
