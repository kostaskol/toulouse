<script setup>
import { computed, ref } from "vue";
import { patch, post } from "../api.js";
import { useAction } from "../action.js";
import { VARIANT_STATUSES, VAT_CLASSES } from "../labels.js";
import { formErrors } from "../messages.js";
import { eurosInput, parseEuros } from "../money.js";
import { notify } from "../notice.js";
import { specificationRows, specificationsParam } from "../specifications.js";
import FormErrors from "./FormErrors.vue";
import FormField from "./FormField.vue";
import SpecificationRows from "./SpecificationRows.vue";

const FIELDS = [
  "option_values", "sku", "barcode", "mpn", "price_cents", "pre_discount_price_cents", "vat_class", "status",
  "track_stock", "allow_oversell", "image_id", "specifications"
];

const props = defineProps({
  product: { type: Object, required: true },
  // Null for a new variant.
  variant: Object,
  definitions: { type: Array, default: () => [] }
});
const emit = defineEmits(["saved", "cancel"]);

const source = props.variant;
const form = ref({
  option_values: Object.fromEntries(
    props.product.option_names.map((name) => [name, source?.option_values[name] ?? ""])
  ),
  sku: source?.sku ?? "", barcode: source?.barcode ?? "", mpn: source?.mpn ?? "",
  price: eurosInput(source?.price_cents), pre_discount_price: eurosInput(source?.pre_discount_price_cents),
  vat_class: source?.vat_class ?? "", status: source?.status ?? "active",
  track_stock: source?.track_stock ?? true, allow_oversell: source?.allow_oversell ?? false,
  image_id: source?.image_id ?? "",
  specifications: specificationRows(source?.specifications ?? [])
});
const priceErrors = ref({});
const { busy, error, run } = useAction();
const errors = computed(() => formErrors(error.value, FIELDS));

async function save() {
  const values = form.value;
  const price_cents = parseEuros(values.price);
  const pre_discount_price_cents = values.pre_discount_price.trim() ? parseEuros(values.pre_discount_price) : null;
  const notAmount = "Γράψτε ποσό σε ευρώ.";
  priceErrors.value = {
    price: price_cents === null ? notAmount : "",
    pre_discount_price: values.pre_discount_price.trim() && pre_discount_price_cents === null ? notAmount : ""
  };
  if (priceErrors.value.price || priceErrors.value.pre_discount_price) return;

  const body = {
    option_values: values.option_values, sku: values.sku || null, barcode: values.barcode || null,
    mpn: values.mpn || null,
    price_cents, pre_discount_price_cents, vat_class: values.vat_class, status: values.status,
    track_stock: values.track_stock, allow_oversell: values.allow_oversell, image_id: values.image_id || null,
    specifications: specificationsParam(values.specifications)
  };
  const path = `/products/${props.product.id}/variants`;
  const done = await run(() => (source ? patch(`${path}/${source.id}`, body) : post(path, body)));
  if (!done) return;

  notify(source ? "Η παραλλαγή αποθηκεύτηκε." : "Η παραλλαγή προστέθηκε.");
  emit("saved");
}
</script>

<template>
  <form class="form" @submit.prevent="save">
    <h2>{{ source ? "Επεξεργασία παραλλαγής" : "Νέα παραλλαγή" }}</h2>
    <FormErrors :messages="errors.base" />
    <div v-if="product.option_names.length" class="form-row">
      <FormField v-for="name in product.option_names" :key="name" :label="name" :error="errors.fields.option_values">
        <input v-model="form.option_values[name]" required>
      </FormField>
    </div>
    <div class="form-row">
      <FormField label="Τιμή (€)" hint="Με ΦΠΑ." :error="priceErrors.price || errors.fields.price_cents">
        <input v-model="form.price" inputmode="decimal" required>
      </FormField>
      <FormField
        label="Αρχική τιμή (€)" hint="Η τιμή πριν την έκπτωση. Κενό χωρίς έκπτωση."
        :error="priceErrors.pre_discount_price || errors.fields.pre_discount_price_cents"
      >
        <input v-model="form.pre_discount_price" inputmode="decimal">
      </FormField>
      <FormField label="Συντελεστής ΦΠΑ" :error="errors.fields.vat_class">
        <select v-model="form.vat_class" required>
          <option value="" disabled>Διαλέξτε</option>
          <option v-for="(label, vat) in VAT_CLASSES" :key="vat" :value="vat">{{ label }}</option>
        </select>
      </FormField>
      <FormField label="Κατάσταση" :error="errors.fields.status">
        <select v-model="form.status">
          <option v-for="(label, status) in VARIANT_STATUSES" :key="status" :value="status">{{ label }}</option>
        </select>
      </FormField>
    </div>
    <div class="form-row">
      <FormField label="SKU" :error="errors.fields.sku"><input v-model="form.sku"></FormField>
      <FormField label="Barcode" :error="errors.fields.barcode"><input v-model="form.barcode"></FormField>
      <FormField label="MPN" :error="errors.fields.mpn"><input v-model="form.mpn"></FormField>
      <FormField label="Φωτογραφία" :error="errors.fields.image_id">
        <select v-model="form.image_id">
          <option value="">Καμία</option>
          <option v-for="(image, index) in product.images" :key="image.id" :value="image.id">
            {{ index + 1 }}. {{ image.alt || "Χωρίς περιγραφή" }}
          </option>
        </select>
      </FormField>
    </div>
    <div class="checks">
      <label class="check"><input v-model="form.track_stock" type="checkbox"> Παρακολούθηση αποθέματος</label>
      <label class="check"><input v-model="form.allow_oversell" type="checkbox"> Πώληση χωρίς απόθεμα</label>
    </div>
    <span v-if="errors.fields.track_stock || errors.fields.allow_oversell" class="field-error">
      {{ errors.fields.track_stock ?? errors.fields.allow_oversell }}
    </span>
    <FormField label="Προδιαγραφές παραλλαγής" group :error="errors.fields.specifications">
      <SpecificationRows v-model="form.specifications" :definitions="definitions" />
    </FormField>
    <div class="form-actions">
      <button class="button button-primary" :disabled="busy">{{ source ? "Αποθήκευση" : "Προσθήκη" }}</button>
      <button type="button" class="button" @click="emit('cancel')">Άκυρο</button>
    </div>
  </form>
</template>
