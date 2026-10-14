<script setup>
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { post } from "../api.js";
import { useAction } from "../action.js";
import { formErrors } from "../messages.js";
import { rememberedSlug } from "../session.js";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";

const route = useRoute();
const slug = ref(route.query.slug || rememberedSlug());
const email = ref("");
const sent = ref(false);
const { busy, error, run } = useAction();
const errors = computed(() => formErrors(error.value));

async function submit() {
  sent.value = await run(() => post("/password_reset", { slug: slug.value.trim(), email: email.value }));
}
</script>

<template>
  <h1>Επαναφορά κωδικού</h1>
  <template v-if="sent">
    <p class="alert alert-success">
      Αν υπάρχει μέλος με αυτό το email, του στείλαμε σύνδεσμο για νέο κωδικό. Ελέγξτε τα εισερχόμενά σας.
    </p>
  </template>
  <form v-else class="form" @submit.prevent="submit">
    <p class="lead">Θα σας στείλουμε σύνδεσμο για να ορίσετε νέο κωδικό.</p>
    <FormErrors :messages="errors.base" />
    <FormField label="Κωδικός καταστήματος">
      <input v-model="slug" required autocapitalize="off">
    </FormField>
    <FormField label="Email">
      <input v-model="email" type="email" required autocomplete="username">
    </FormField>
    <button class="button button-primary" :disabled="busy">Αποστολή συνδέσμου</button>
  </form>
  <p class="auth-links"><RouterLink to="/login">Επιστροφή στη σύνδεση</RouterLink></p>
</template>
