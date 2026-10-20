<script setup>
import { computed, reactive, ref } from "vue";
import DOMPurify from "dompurify";
import { marked } from "marked";
import { shop } from "../shop.js";
import { store, SHOP_NAME } from "../store.js";
import { errorMessage } from "../messages.js";
import ProductImage from "../components/ProductImage.vue";
import ProductPrice from "../components/ProductPrice.vue";
import NotFoundPage from "./NotFoundPage.vue";

const props = defineProps({ slug: { type: String, required: true } });

const product = ref(null);
const notFound = ref(false);
const error = ref(null);
const selected = reactive({});
const cartNote = ref(null);
const cartError = ref(null);
const adding = ref(false);

// Every active variant has a value for each selectable spec, so the first one names the pickers in order.
const names = computed(() => Object.keys(product.value.variants[0]?.selection ?? {}));
const matches = (variant, choice) => names.value.every((name) => variant.selection[name] === choice[name]);
const variant = computed(() => product.value.variants.find((candidate) => matches(candidate, selected)));
// The merchant writes the Markdown, so it is sanitized before it becomes HTML.
const description = computed(() => DOMPurify.sanitize(marked.parse(product.value.description ?? "")));

// A variant's specs replace the product's of the same name.
const specifications = computed(() => {
  const merged = new Map(product.value.specifications.map((spec) => [spec.name, spec.values]));
  for (const spec of variant.value?.specifications ?? []) merged.set(spec.name, spec.values);
  return [...merged];
});

const valuesOf = (name) => [...new Set(product.value.variants.map((candidate) => candidate.selection[name]))];
// Only the pickers up to this one count, so no buyable variant is ever out of reach.
const buyableWith = (name, value) => {
  const earlier = names.value.slice(0, names.value.indexOf(name) + 1);
  const choice = { ...selected, [name]: value };
  return product.value.variants.find((candidate) =>
    candidate.available && earlier.every((picker) => candidate.selection[picker] === choice[picker]));
};

const select = (name, value) => {
  const fallback = buyableWith(name, value);
  selected[name] = value;
  if (!variant.value?.available) Object.assign(selected, fallback.selection);
  cartNote.value = null;
  cartError.value = null;
};

async function addToCart() {
  adding.value = true;
  cartNote.value = null;
  cartError.value = null;
  try {
    const response = await shop.addToCart(variant.value.id);
    store.cart = response.cart;
    cartNote.value = shop.hasWarning(response, "quantity_reduced")
      ? "Έχετε ήδη στο καλάθι όλα τα διαθέσιμα κομμάτια."
      : "Προστέθηκε στο καλάθι.";
  } catch (failure) {
    cartError.value = errorMessage(failure);
  } finally {
    adding.value = false;
  }
}

try {
  ({ product: product.value } = await shop.getProduct(props.slug));
  const first = product.value.variants.find((candidate) => candidate.available) ?? product.value.variants[0];
  Object.assign(selected, first.selection);
  document.title = `${product.value.title} · ${SHOP_NAME}`;
} catch (failure) {
  if (failure.code === "not_found") notFound.value = true;
  else error.value = errorMessage(failure);
}
</script>

<template>
  <NotFoundPage v-if="notFound" />
  <p v-else-if="error" class="form-error">{{ error }}</p>
  <article v-else class="product">
    <ProductImage :product="product" />
    <div class="product-details">
      <p class="product-brand">{{ product.brand?.name }}</p>
      <h1>{{ product.title }}</h1>
      <ProductPrice v-if="variant" :price="variant.price_cents" :pre-discount="variant.pre_discount_price_cents" />

      <fieldset v-for="name in names" :key="name" class="option">
        <legend>{{ name }}: <strong>{{ selected[name] }}</strong></legend>
        <button v-for="value in valuesOf(name)" :key="value" type="button" class="option-value"
                :class="{ selected: selected[name] === value }" :disabled="!buyableWith(name, value)"
                :aria-pressed="selected[name] === value" @click="select(name, value)">
          {{ value }}
        </button>
      </fieldset>

      <p v-if="variant && !variant.available" class="stock-out">Εξαντλήθηκε</p>
      <button class="button button-wide" :disabled="!variant?.available || adding" @click="addToCart">
        Προσθήκη στο καλάθι
      </button>
      <p v-if="cartError" class="form-error">{{ cartError }}</p>
      <p v-if="cartNote" class="muted">{{ cartNote }} <RouterLink to="/cart">Δείτε το καλάθι</RouterLink></p>

      <div class="description" v-html="description" />

      <section v-if="specifications.length">
        <h2>Χαρακτηριστικά</h2>
        <dl class="specifications">
          <template v-for="[name, values] in specifications" :key="name">
            <dt>{{ name }}</dt>
            <dd>{{ values.join(", ") }}</dd>
          </template>
        </dl>
      </section>
    </div>
  </article>
</template>
