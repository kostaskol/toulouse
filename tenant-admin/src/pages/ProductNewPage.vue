<script setup>
import { computed, onMounted, reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { post } from "../api.js";
import { useAction } from "../action.js";
import { flatten, loadCategories } from "../categories.js";
import { PRODUCT_STATUSES, VAT_CLASSES } from "../labels.js";
import { formErrors } from "../messages.js";
import { parseEuros } from "../money.js";
import { notify } from "../notice.js";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";

// The API indexes nested errors by variant.
const FIELDS = [
  "title", "status", "category_id", "variants[0].price_cents", "variants[0].sku", "variants[0].vat_class"
];

const router = useRouter();
const form = reactive({ title: "", status: "draft", category_id: "", price: "", sku: "", vat_class: "" });
const categories = ref(null);
const priceInvalid = ref(false);
const loading = useAction();
const { busy, error, run } = useAction();
const errors = computed(() => formErrors(error.value, FIELDS));

onMounted(() => loading.run(async () => (categories.value = flatten(await loadCategories()))));

async function submit() {
  const price_cents = parseEuros(form.price);
  priceInvalid.value = price_cents === null;
  if (priceInvalid.value) return;

  let product;
  const done = await run(async () => {
    ({ product } = await post("/products", {
      title: form.title, status: form.status, category_id: form.category_id,
      variants: [{ price_cents, sku: form.sku || undefined, vat_class: form.vat_class }]
    }));
  });
  if (!done) return;

  notify("Το προϊόν δημιουργήθηκε.");
  router.replace(`/products/${product.id}`);
}
</script>

<template>
  <div class="page-head">
    <div>
      <RouterLink to="/products" class="back">← Προϊόντα</RouterLink>
      <h1>Νέο προϊόν</h1>
    </div>
  </div>

  <FormErrors :messages="formErrors(loading.error.value).base" />
  <section v-if="categories?.length === 0" class="panel">
    <p>
      Κάθε προϊόν ανήκει σε μια κατηγορία.
      <RouterLink to="/categories">Δημιουργήστε πρώτα μια κατηγορία.</RouterLink>
    </p>
  </section>
  <section v-else-if="categories" class="panel">
    <FormErrors :messages="errors.base" />
    <form class="form" @submit.prevent="submit">
      <FormField label="Τίτλος" :error="errors.fields.title"><input v-model="form.title" required></FormField>
      <FormField label="Κατηγορία" :error="errors.fields.category_id">
        <select v-model="form.category_id" required>
          <option value="" disabled>Διαλέξτε</option>
          <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.label }}</option>
        </select>
      </FormField>
      <div class="form-row">
        <FormField label="Κατάσταση" :error="errors.fields.status">
          <select v-model="form.status">
            <option v-for="(label, status) in PRODUCT_STATUSES" :key="status" :value="status">{{ label }}</option>
          </select>
        </FormField>
        <FormField
          label="Τιμή (€)" hint="Με ΦΠΑ."
          :error="priceInvalid ? 'Γράψτε ποσό σε ευρώ.' : errors.fields['variants[0].price_cents']"
        >
          <input v-model="form.price" inputmode="decimal" required>
        </FormField>
        <FormField label="Συντελεστής ΦΠΑ" :error="errors.fields['variants[0].vat_class']">
          <select v-model="form.vat_class" required>
            <option value="" disabled>Διαλέξτε</option>
            <option v-for="(label, vat) in VAT_CLASSES" :key="vat" :value="vat">{{ label }}</option>
          </select>
        </FormField>
        <FormField label="SKU" :error="errors.fields['variants[0].sku']"><input v-model="form.sku"></FormField>
      </div>
      <p class="hint">Τα υπόλοιπα στοιχεία, οι παραλλαγές και οι φωτογραφίες προστίθενται μετά τη δημιουργία.</p>
      <div class="form-actions">
        <button class="button button-primary" :disabled="busy">Δημιουργία</button>
      </div>
    </form>
  </section>
</template>
