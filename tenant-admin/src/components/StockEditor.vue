<script setup>
import { computed, ref } from "vue";
import { put } from "../api.js";
import { useAction } from "../action.js";
import { formErrors } from "../messages.js";
import { notify } from "../notice.js";
import FormErrors from "./FormErrors.vue";
import FormField from "./FormField.vue";

const props = defineProps({ productId: { type: String, required: true }, variant: { type: Object, required: true } });
const emit = defineEmits(["saved", "cancel"]);
const mode = ref("delta");
const amount = ref("");
const reason = ref("");
const { busy, error, run } = useAction();
const errors = computed(() => formErrors(error.value, ["stock_quantity"]));

async function save() {
  const number = Number(amount.value);
  const body = mode.value === "quantity" ? { quantity: number } : { delta: number };
  const path = `/products/${props.productId}/variants/${props.variant.id}/stock`;
  if (await run(() => put(path, { ...body, reason: reason.value || undefined }))) {
    notify("Το απόθεμα άλλαξε.");
    emit("saved");
  }
}
</script>

<template>
  <form class="form" @submit.prevent="save">
    <h2>Απόθεμα: {{ variant.stock_quantity }}</h2>
    <FormErrors :messages="[...errors.base, errors.fields.stock_quantity].filter(Boolean)" />
    <div class="checks">
      <label class="check"><input v-model="mode" type="radio" value="delta"> Πρόσθεση ή αφαίρεση</label>
      <label class="check"><input v-model="mode" type="radio" value="quantity"> Ορισμός μετρημένου αποθέματος</label>
    </div>
    <div class="form-row">
      <FormField
        :label="mode === 'delta' ? 'Αλλαγή' : 'Νέο απόθεμα'"
        :hint="mode === 'delta' ? 'Αρνητικός αριθμός για αφαίρεση.' : ''"
      >
        <input v-model="amount" type="number" step="1" required>
      </FormField>
      <FormField label="Αιτία"><input v-model="reason"></FormField>
    </div>
    <div class="form-actions">
      <button class="button button-primary" :disabled="busy">Αποθήκευση</button>
      <button type="button" class="button" @click="emit('cancel')">Άκυρο</button>
    </div>
  </form>
</template>
