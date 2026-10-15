<script setup>
import { computed, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { post } from "../api.js";
import { useAction } from "../action.js";
import { formErrors } from "../messages.js";
import { setSession } from "../session.js";
import { store } from "../store.js";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";

const route = useRoute();
const router = useRouter();
const slug = ref(store.slug || String(route.query.slug ?? ""));
const email = ref("");
const password = ref("");
const { busy, error, run } = useAction();
const errors = computed(() => formErrors(error.value));

async function submit() {
  const done = await run(async () => {
    setSession(await post("/session", { slug: slug.value.trim(), email: email.value, password: password.value }));
  });
  if (!done) return;

  // Only a path inside the app, so a crafted link cannot send the member elsewhere.
  const next = String(route.query.next ?? "");
  router.replace(next.startsWith("/") && !next.startsWith("//") ? next : "/");
}
</script>

<template>
  <h1>Σύνδεση</h1>
  <p class="lead">Συνδεθείτε στη διαχείριση του καταστήματός σας.</p>
  <form class="form" @submit.prevent="submit">
    <FormErrors :messages="errors.base" />
    <FormField v-if="!store.slug" label="Κωδικός καταστήματος">
      <input v-model="slug" required autocomplete="organization" autocapitalize="off">
    </FormField>
    <FormField label="Email">
      <input v-model="email" type="email" required autocomplete="username">
    </FormField>
    <FormField label="Κωδικός πρόσβασης">
      <input v-model="password" type="password" required autocomplete="current-password">
    </FormField>
    <button class="button button-primary" :disabled="busy">Σύνδεση</button>
  </form>
  <p class="auth-links">
    <RouterLink :to="{ path: '/forgot-password', query: { slug } }">Ξεχάσατε τον κωδικό;</RouterLink>
  </p>
</template>
