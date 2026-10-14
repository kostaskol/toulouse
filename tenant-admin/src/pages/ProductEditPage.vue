<script setup>
import { computed, onMounted, ref } from "vue";
import { get, patch } from "../api.js";
import { useAction } from "../action.js";
import { flatten, loadCategories } from "../categories.js";
import { PRODUCT_STATUSES } from "../labels.js";
import { getAll } from "../list.js";
import { formErrors } from "../messages.js";
import { notify } from "../notice.js";
import { specificationRows, specificationsParam } from "../specifications.js";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";
import ProductImages from "../components/ProductImages.vue";
import ProductOptions from "../components/ProductOptions.vue";
import ProductVariants from "../components/ProductVariants.vue";
import SpecificationRows from "../components/SpecificationRows.vue";

const FIELDS = ["title", "slug", "description", "status", "brand_id", "category_ids", "specifications"];

const props = defineProps({ id: { type: String, required: true } });
const path = `/products/${props.id}`;
const product = ref(null);
const form = ref(null);
const options = ref({ brands: [], categories: [], specifications: [] });
const loading = useAction();
const saving = useAction();
const errors = computed(() => formErrors(saving.error.value, FIELDS));

onMounted(() => loading.run(async () => {
  const [body, brands, categories, { specifications }] = await Promise.all([
    get(path), getAll("/brands", "brands"), loadCategories(), get("/specifications")
  ]);
  options.value = { brands, categories: flatten(categories), specifications };
  show(body.product);
}));

/**
 * @param loaded [Object] the product as the API returns it
 */
function show(loaded) {
  product.value = loaded;
  form.value = {
    title: loaded.title, slug: loaded.slug, description: loaded.description ?? "", status: loaded.status,
    brand_id: loaded.brand?.id ?? "", category_ids: [...loaded.category_ids],
    specifications: specificationRows(loaded.specifications)
  };
}

// Keeps unsaved edits in the details form.
async function refresh() {
  await loading.run(async () => (product.value = (await get(path)).product));
}

async function save() {
  const { title, slug, description, status, brand_id, category_ids, specifications } = form.value;
  const done = await saving.run(async () => {
    const body = await patch(path, {
      title, slug: slug || undefined, description: description || null, status, brand_id: brand_id || null,
      category_ids, specifications: specificationsParam(specifications)
    });
    show(body.product);
  });
  if (done) notify("Το προϊόν αποθηκεύτηκε.");
}
</script>

<template>
  <div class="page-head">
    <div>
      <RouterLink to="/products" class="back">← Προϊόντα</RouterLink>
      <h1>{{ product?.title ?? "Προϊόν" }}</h1>
    </div>
  </div>
  <FormErrors :messages="formErrors(loading.error.value).base" />

  <template v-if="product">
    <section class="panel">
      <h2>Στοιχεία</h2>
      <FormErrors :messages="errors.base" />
      <form class="form" @submit.prevent="save">
        <FormField label="Τίτλος" :error="errors.fields.title"><input v-model="form.title" required></FormField>
        <div class="form-row">
          <FormField label="Slug" hint="Κενό για αυτόματο." :error="errors.fields.slug">
            <input v-model="form.slug">
          </FormField>
          <FormField label="Κατάσταση" :error="errors.fields.status">
            <select v-model="form.status">
              <option v-for="(label, status) in PRODUCT_STATUSES" :key="status" :value="status">{{ label }}</option>
            </select>
          </FormField>
          <FormField label="Μάρκα" :error="errors.fields.brand_id">
            <select v-model="form.brand_id">
              <option value="">Χωρίς μάρκα</option>
              <option v-for="brand in options.brands" :key="brand.id" :value="brand.id">{{ brand.name }}</option>
            </select>
          </FormField>
        </div>
        <FormField label="Περιγραφή" hint="Δέχεται Markdown." :error="errors.fields.description">
          <textarea v-model="form.description"></textarea>
        </FormField>
        <FormField label="Κατηγορίες" group :error="errors.fields.category_ids">
          <div class="check-list">
            <label
              v-for="category in options.categories" :key="category.id" class="check"
              :style="{ paddingLeft: `${category.depth * 20}px` }"
            >
              <input v-model="form.category_ids" type="checkbox" :value="category.id"> {{ category.name }}
            </label>
            <span v-if="!options.categories.length" class="muted small">Δεν υπάρχουν κατηγορίες.</span>
          </div>
        </FormField>
        <FormField label="Προδιαγραφές" group :error="errors.fields.specifications">
          <SpecificationRows v-model="form.specifications" :definitions="options.specifications" />
        </FormField>
        <div class="form-actions">
          <button class="button button-primary" :disabled="saving.busy.value">Αποθήκευση</button>
        </div>
      </form>
    </section>
    <ProductImages :product="product" @changed="refresh" />
    <ProductOptions :product="product" @changed="refresh" />
    <ProductVariants :product="product" :definitions="options.specifications" @changed="refresh" />
  </template>
</template>
