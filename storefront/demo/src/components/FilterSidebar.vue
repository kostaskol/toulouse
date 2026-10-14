<script setup>
import { formatPrice } from "../format.js";
import FacetCategories from "./FacetCategories.vue";

// `facets` is the API's facets object. `filter` is what the page URL holds.
const props = defineProps({
  facets: { type: Object, required: true },
  filter: { type: Object, required: true }
});
const emit = defineEmits(["change"]);

const toggled = (list = [], value) => (list.includes(value) ? list.filter((item) => item !== value) : [...list, value]);
const change = (patch) => emit("change", { ...props.filter, ...patch });

function toggleAttribute(key, value) {
  const attributes = { ...props.filter.attributes, [key]: toggled(props.filter.attributes?.[key], value) };
  if (!attributes[key].length) delete attributes[key];
  change({ attributes });
}

const rangePicked = (range) =>
  props.filter.price_min === (range.min ?? undefined) && props.filter.price_max === (range.max ?? undefined);

function pickRange(range) {
  if (rangePicked(range)) return change({ price_min: undefined, price_max: undefined });
  change({ price_min: range.min ?? undefined, price_max: range.max ?? undefined });
}

function rangeLabel(range) {
  if (range.min == null) return `Έως ${formatPrice(range.max)}`;
  if (range.max == null) return `Από ${formatPrice(range.min)}`;
  return `${formatPrice(range.min)} – ${formatPrice(range.max)}`;
}
</script>

<template>
  <aside class="filters">
    <label class="facet-check">
      <input type="checkbox" :checked="filter.available" @change="change({ available: $event.target.checked })" />
      Μόνο διαθέσιμα
    </label>

    <section v-if="facets.categories.length">
      <h2>Κατηγορία</h2>
      <FacetCategories
        :categories="facets.categories"
        :picked="filter.categories ?? []"
        @toggle="(slug) => change({ categories: toggled(filter.categories, slug) })"
      />
    </section>

    <section v-if="facets.brands.length">
      <h2>Κατασκευαστής</h2>
      <label v-for="brand in facets.brands" :key="brand.slug" class="facet-check">
        <input
          type="checkbox"
          :checked="filter.brands?.includes(brand.slug)"
          @change="change({ brands: toggled(filter.brands, brand.slug) })"
        />
        {{ brand.name }} <span class="muted">({{ brand.count }})</span>
      </label>
    </section>

    <section v-if="facets.price.ranges.length">
      <h2>Τιμή</h2>
      <label v-for="range in facets.price.ranges" :key="`${range.min}-${range.max}`" class="facet-check">
        <input type="checkbox" :checked="rangePicked(range)" @change="pickRange(range)" />
        {{ rangeLabel(range) }} <span class="muted">({{ range.count }})</span>
      </label>
    </section>

    <section v-for="group in facets.attributes" :key="group.key">
      <h2>{{ group.label }}</h2>
      <label v-for="value in group.values" :key="value.key" class="facet-check">
        <input
          type="checkbox"
          :checked="filter.attributes?.[group.key]?.includes(value.key)"
          @change="toggleAttribute(group.key, value.key)"
        />
        {{ value.label }} <span class="muted">({{ value.count }})</span>
      </label>
    </section>

    <button v-if="Object.keys(filter).length" class="link-button" @click="emit('change', {})">
      Καθαρισμός φίλτρων
    </button>
  </aside>
</template>
