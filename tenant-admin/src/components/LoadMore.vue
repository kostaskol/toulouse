<script setup>
defineProps({ next: String, busy: Boolean });
defineEmits(["more"]);
</script>

<template>
  <div v-if="next" class="form-actions" style="margin-top: 12px">
    <button class="button" :disabled="busy" @click="$emit('more')">Περισσότερα</button>
  </div>
</template>
