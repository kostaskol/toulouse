<script setup>
import { useId } from "vue";

defineProps({ definitions: { type: Array, default: () => [] } });
const rows = defineModel({ type: Array, required: true });
const listId = useId();
</script>

<template>
  <div class="form">
    <datalist :id="listId">
      <option v-for="definition in definitions" :key="definition.id" :value="definition.name" />
    </datalist>
    <div v-for="(row, index) in rows" :key="index" class="row">
      <input v-model="row.name" :list="listId" placeholder="Όνομα" style="flex: 1 1 160px">
      <input v-model="row.values" placeholder="Τιμές, χωρισμένες με κόμμα" style="flex: 2 1 240px">
      <button type="button" class="button button-small button-danger" @click="rows.splice(index, 1)">Αφαίρεση</button>
    </div>
    <div>
      <button type="button" class="button button-small" @click="rows.push({ name: '', values: '' })">
        + Προδιαγραφή
      </button>
    </div>
  </div>
</template>
