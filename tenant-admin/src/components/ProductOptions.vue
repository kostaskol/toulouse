<script setup>
import { computed, ref, watch } from "vue";
import { put } from "../api.js";
import { useAction } from "../action.js";
import { formErrors } from "../messages.js";
import { notify } from "../notice.js";

const props = defineProps({ product: { type: Object, required: true } });
const emit = defineEmits(["changed"]);
const rows = ref([]);
const { busy, error, run } = useAction();
const errors = computed(() => formErrors(error.value, ["option_names"]));

// Keyed on the names, so a refresh after another panel saves keeps unsaved edits here.
watch(() => props.product.option_names.join("\u0000"), () => {
  rows.value = props.product.option_names.map((name) => ({ name, from: name }));
}, { immediate: true });

function move(index, step) {
  const [row] = rows.value.splice(index, 1);
  rows.value.splice(index + step, 0, row);
}

async function save() {
  const option_names = rows.value.map(({ name, from, value }) => (from ? { name, from } : { name, value }));
  if (await run(() => put(`/products/${props.product.id}/options`, { option_names }))) {
    notify("Οι επιλογές αποθηκεύτηκαν.");
    emit("changed");
  }
}
</script>

<template>
  <section class="panel">
    <div class="panel-head"><h2>Επιλογές</h2></div>
    <p class="hint">
      Οι επιλογές ξεχωρίζουν τις παραλλαγές μεταξύ τους. Μια νέα επιλογή παίρνει την ίδια τιμή σε κάθε παραλλαγή.
    </p>
    <div
      v-for="message in [...errors.base, errors.fields.option_names].filter(Boolean)" :key="message"
      class="alert alert-error"
    >
      {{ message }}
    </div>
    <form class="form" @submit.prevent="save">
      <div v-for="(row, index) in rows" :key="index" class="row">
        <input v-model="row.name" required placeholder="Όνομα επιλογής" style="flex: 1 1 160px">
        <input
          v-if="!row.from" v-model="row.value" required placeholder="Τιμή για κάθε παραλλαγή" style="flex: 1 1 160px"
        >
        <span v-else-if="row.from !== row.name" class="muted small">πρώην «{{ row.from }}»</span>
        <button type="button" class="button button-small" :disabled="index === 0" @click="move(index, -1)">↑</button>
        <button
          type="button" class="button button-small" :disabled="index === rows.length - 1" @click="move(index, 1)"
        >
          ↓
        </button>
        <button type="button" class="button button-small button-danger" @click="rows.splice(index, 1)">Αφαίρεση</button>
      </div>
      <div class="form-actions">
        <button type="button" class="button button-small" @click="rows.push({ name: '', from: null, value: '' })">
          + Επιλογή
        </button>
      </div>
      <div class="form-actions">
        <button class="button button-primary" :disabled="busy">Αποθήκευση επιλογών</button>
      </div>
    </form>
  </section>
</template>
