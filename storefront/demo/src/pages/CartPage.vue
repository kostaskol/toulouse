<script setup>
import { ref } from "vue";
import { shop } from "../shop.js";
import { loadCart, store, SHOP_NAME } from "../store.js";
import { errorMessage } from "../messages.js";
import { formatPrice } from "../format.js";
import ProductImage from "../components/ProductImage.vue";
import ProductPrice from "../components/ProductPrice.vue";

document.title = `Καλάθι · ${SHOP_NAME}`;

const error = ref(null);
const note = ref(null);
const busy = ref(false);

await loadCart();

async function change(action) {
  busy.value = true;
  error.value = null;
  note.value = null;
  try {
    const response = await action();
    store.cart = response.cart;
    if (shop.hasWarning(response, "quantity_reduced")) note.value = "Δεν υπάρχουν άλλα διαθέσιμα κομμάτια.";
  } catch (failure) {
    error.value = errorMessage(failure);
  } finally {
    busy.value = false;
  }
}

const setQuantity = (line, quantity) => change(() => shop.setCartQuantity(line.variant_id, quantity));
const remove = (line) => change(() => shop.removeFromCart(line.variant_id));
const selectionText = (line) => Object.entries(line.selection).map(([name, value]) => `${name}: ${value}`).join(" · ");
</script>

<template>
  <section class="cart">
    <h1>Καλάθι</h1>
    <p v-if="error" class="form-error">{{ error }}</p>
    <p v-if="note" class="muted" role="status">{{ note }}</p>

    <p v-if="!store.cart?.lines.length" class="muted">
      Το καλάθι σας είναι άδειο. <RouterLink to="/">Συνεχίστε τις αγορές</RouterLink>
    </p>

    <template v-else>
      <ul class="cart-lines">
        <li v-for="line in store.cart.lines" :key="line.variant_id" class="cart-line"
            :class="{ 'cart-line-unavailable': line.state === 'unavailable' }">
          <RouterLink :to="`/products/${line.product.slug}`" class="cart-line-image">
            <ProductImage :product="line.product" />
          </RouterLink>
          <div class="cart-line-details">
            <RouterLink :to="`/products/${line.product.slug}`">{{ line.product.title }}</RouterLink>
            <p v-if="selectionText(line)" class="muted">{{ selectionText(line) }}</p>
            <ProductPrice :price="line.price_cents" :pre-discount="line.pre_discount_price_cents" />
            <p v-if="line.state === 'over_stock'" class="stock-out">
              Μόνο {{ line.available_quantity }} διαθέσιμα. Μειώστε την ποσότητα.
            </p>
            <p v-if="line.state === 'unavailable'" class="stock-out">Δεν είναι πια διαθέσιμο.</p>
          </div>
          <div class="cart-line-quantity">
            <button class="option-value" :disabled="busy || line.quantity <= 1 || line.state === 'unavailable'"
                    aria-label="Μείωση ποσότητας" @click="setQuantity(line, line.quantity - 1)">−</button>
            <span>{{ line.quantity }}</span>
            <button class="option-value" :disabled="busy || line.state !== 'buyable'"
                    aria-label="Αύξηση ποσότητας" @click="setQuantity(line, line.quantity + 1)">+</button>
          </div>
          <div class="cart-line-total">
            <strong>{{ formatPrice(line.total_cents) }}</strong>
            <button class="link-button" :disabled="busy" @click="remove(line)">Αφαίρεση</button>
          </div>
        </li>
      </ul>

      <div class="cart-summary">
        <p>Σύνολο <strong>{{ formatPrice(store.cart.subtotal_cents) }}</strong></p>
        <p class="hint">Οι τιμές περιλαμβάνουν ΦΠΑ.</p>
        <button class="button button-wide" disabled>Ολοκλήρωση παραγγελίας</button>
        <p class="muted">Η ολοκλήρωση παραγγελίας έρχεται σύντομα.</p>
      </div>
    </template>
  </section>
</template>
