<script setup>
import { useId, watch } from "vue";
import { blankSpecificationRow } from "../specifications.js";

defineProps({ definitions: { type: Array, default: () => [] } });
const rows = defineModel({ type: Array, required: true });
// Messages by row index, from the last save.
const errors = defineModel("errors", { type: Object, default: () => ({}) });
const listId = useId();
// Cleared on any edit, since a removed row would shift the indexes under the messages.
watch(rows, () => (errors.value = {}), { deep: true });
</script>

<template>
  <div class="form">
    <datalist :id="listId">
      <option v-for="definition in definitions" :key="definition.id" :value="definition.name" />
    </datalist>
    <div v-for="(row, index) in rows" :key="index" class="spec-row" :class="{ 'field-invalid': errors[index] }">
      <div class="row">
        <input
          v-model="row.name" :list="listId" placeholder="Όνομα" aria-label="Όνομα προδιαγραφής" class="spec-name"
          :aria-invalid="Boolean(errors[index])" :aria-describedby="errors[index] ? `${listId}-${index}` : undefined"
        >
        <div class="spec-values">
          <span v-for="(value, valueIndex) in row.values" :key="valueIndex" class="row">
            <input
              v-model="row.values[valueIndex]" placeholder="Τιμή" class="spec-value"
              :aria-label="`Τιμή για ${row.name || 'νέα προδιαγραφή'}`" :aria-invalid="Boolean(errors[index])"
              :aria-describedby="errors[index] ? `${listId}-${index}` : undefined"
            >
            <button
              v-if="row.values.length > 1" type="button" class="button button-small" aria-label="Αφαίρεση τιμής"
              @click="row.values.splice(valueIndex, 1)"
            >
              ×
            </button>
          </span>
          <button type="button" class="button button-small" @click="row.values.push('')">+ Τιμή</button>
        </div>
        <button
          type="button" class="button button-small button-danger"
          :aria-label="`Αφαίρεση προδιαγραφής ${row.name || 'χωρίς όνομα'}`" @click="rows.splice(index, 1)"
        >
          Αφαίρεση
        </button>
      </div>
      <span v-if="errors[index]" :id="`${listId}-${index}`" class="field-error">{{ errors[index] }}</span>
    </div>
    <div>
      <button type="button" class="button button-small" @click="rows.push(blankSpecificationRow())">
        + Προδιαγραφή
      </button>
    </div>
  </div>
</template>
