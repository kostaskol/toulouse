<script setup>
import { computed, ref } from "vue";
import { VARIANT_STATUSES } from "../labels.js";
import { formatPrice } from "../money.js";
import StockEditor from "./StockEditor.vue";
import VariantEditor from "./VariantEditor.vue";

const props = defineProps({
  product: { type: Object, required: true },
  definitions: { type: Array, default: () => [] }
});
const emit = defineEmits(["changed"]);
// What the panel below the table shows: { kind: "variant" | "stock", variant }.
const open = ref(null);

// Archived variants may lack a value, so the names come from every variant.
const selectable = computed(() =>
  [...new Set(props.product.variants.flatMap((variant) => Object.keys(variant.selection)))]);
const selectionLabel = (variant) => selectable.value.map((name) => variant.selection[name] ?? "—").join(" / ");

function saved() {
  open.value = null;
  emit("changed");
}
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <h2>Παραλλαγές</h2>
      <button class="button button-small" @click="open = { kind: 'variant', variant: null }">+ Παραλλαγή</button>
    </div>
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th v-if="selectable.length">{{ selectable.join(" / ") }}</th>
            <th>SKU</th><th class="num">Τιμή</th><th class="num">Απόθεμα</th><th>Κατάσταση</th><th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="variant in product.variants" :key="variant.id">
            <td v-if="selectable.length">{{ selectionLabel(variant) }}</td>
            <td class="muted nowrap">{{ variant.sku }}</td>
            <td class="num nowrap">
              {{ formatPrice(variant.price_cents) }}
              <s v-if="variant.pre_discount_price_cents" class="muted small">
                {{ formatPrice(variant.pre_discount_price_cents) }}
              </s>
            </td>
            <td class="num">
              <template v-if="variant.track_stock">{{ variant.stock_quantity }}</template>
              <span v-else class="muted">—</span>
            </td>
            <td>
              <span class="badge" :class="{ 'badge-green': variant.status === 'active' }">
                {{ VARIANT_STATUSES[variant.status] }}
              </span>
            </td>
            <td class="actions">
              <button class="button button-small" @click="open = { kind: 'stock', variant }">Απόθεμα</button>
              <button class="button button-small" @click="open = { kind: 'variant', variant }">Επεξεργασία</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div v-if="open" style="margin-top: 20px">
      <VariantEditor
        v-if="open.kind === 'variant'" :key="open.variant?.id ?? 'new'"
        :product="product" :variant="open.variant" :definitions="definitions" @saved="saved" @cancel="open = null"
      />
      <StockEditor
        v-else :key="`stock-${open.variant.id}`"
        :product-id="product.id" :variant="open.variant" @saved="saved" @cancel="open = null"
      />
    </div>
  </section>
</template>
