<script setup>
// A group holds several inputs, and a label must not wrap more than one.
defineProps({ label: String, error: String, hint: String, group: Boolean });
</script>

<template>
  <component :is="group ? 'div' : 'label'" class="field" :class="{ 'field-invalid': error }">
    <span class="field-label">{{ label }}</span>
    <slot />
    <span v-if="hint" class="hint">{{ hint }}</span>
    <span v-if="error" class="field-error">{{ error }}</span>
  </component>
</template>
