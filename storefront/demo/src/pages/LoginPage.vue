<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { shop } from "../shop.js";
import { signedIn, SHOP_NAME } from "../store.js";
import { errorMessage } from "../messages.js";

document.title = `Σύνδεση · ${SHOP_NAME}`;

const router = useRouter();
const email = ref("");
const password = ref("");
const error = ref(null);
const busy = ref(false);

async function signIn() {
  busy.value = true;
  error.value = null;
  try {
    signedIn(await shop.signIn({ email: email.value, password: password.value }));
    router.push("/");
  } catch (failure) {
    error.value = errorMessage(failure);
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <section class="auth">
    <h1>Σύνδεση</h1>
    <form @submit.prevent="signIn">
      <label>Email <input v-model="email" type="email" autocomplete="email" required></label>
      <label>Κωδικός πρόσβασης
        <input v-model="password" type="password" autocomplete="current-password" required>
      </label>
      <button class="button button-wide" :disabled="busy">Σύνδεση</button>
    </form>
    <p v-if="error" class="form-error">{{ error }}</p>
    <p><RouterLink to="/forgot-password">Ξεχάσατε τον κωδικό πρόσβασης;</RouterLink></p>
    <p>Νέος πελάτης; <RouterLink to="/signup">Δημιουργία λογαριασμού</RouterLink></p>
  </section>
</template>
