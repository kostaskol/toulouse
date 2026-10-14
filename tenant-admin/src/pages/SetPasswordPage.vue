<script setup>
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { put } from "../api.js";
import { useAction } from "../action.js";
import { formErrors } from "../messages.js";
import { rememberSlug, setSession } from "../session.js";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";

const COPY = {
  reset: { title: "Νέος κωδικός", lead: "Ορίστε νέο κωδικό πρόσβασης.", path: "/password_reset" },
  invite: { title: "Αποδοχή πρόσκλησης", lead: "Ορίστε κωδικό για να μπείτε στο κατάστημα.", path: "/invite" }
};

const props = defineProps({ kind: { type: String, required: true } });
const route = useRoute();
const router = useRouter();
const copy = COPY[props.kind];
const slug = String(route.query.slug ?? "");
const token = ref("");
const password = ref("");
const confirmation = ref("");
const mismatch = ref(false);
const { busy, error, run } = useAction();
const errors = computed(() => formErrors(error.value));

onMounted(() => {
  token.value = route.hash.slice(1);
  // Keeps the token out of history and out of a copied URL.
  if (token.value) router.replace({ query: route.query, hash: "" });
});

async function submit() {
  mismatch.value = password.value !== confirmation.value;
  if (mismatch.value) return;

  const done = await run(async () => {
    setSession(await put(copy.path, { slug, token: token.value, password: password.value }));
  });
  if (!done) return;

  rememberSlug(slug);
  router.replace("/");
}
</script>

<template>
  <h1>{{ copy.title }}</h1>
  <p v-if="!token || !slug" class="alert alert-error">
    Ο σύνδεσμος δεν είναι πλήρης. Ανοίξτε τον ξανά από το email.
  </p>
  <form v-else class="form" @submit.prevent="submit">
    <p class="lead">{{ copy.lead }}</p>
    <FormErrors :messages="errors.base" />
    <FormField label="Νέος κωδικός πρόσβασης" hint="Τουλάχιστον 12 χαρακτήρες.">
      <input v-model="password" type="password" required minlength="12" autocomplete="new-password">
    </FormField>
    <FormField label="Επαναλάβετε τον κωδικό" :error="mismatch ? 'Οι κωδικοί δεν ταιριάζουν.' : ''">
      <input v-model="confirmation" type="password" required autocomplete="new-password">
    </FormField>
    <button class="button button-primary" :disabled="busy">Αποθήκευση κωδικού</button>
  </form>
  <p class="auth-links"><RouterLink to="/login">Επιστροφή στη σύνδεση</RouterLink></p>
</template>
