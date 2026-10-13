<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { store } from "../store.js";
import { errorMessage } from "../messages.js";

// Signup and password reset share this shape: an email step, then a code and password step.
const props = defineProps({
  title: { type: String, required: true },
  sentMessage: { type: String, required: true },
  submitLabel: { type: String, required: true },
  requestCode: { type: Function, required: true },
  complete: { type: Function, required: true }
});

const router = useRouter();
const step = ref("email");
const email = ref("");
const code = ref("");
const password = ref("");
const error = ref(null);
const busy = ref(false);
const resent = ref(false);

async function run(action) {
  busy.value = true;
  error.value = null;
  try {
    await action();
  } catch (failure) {
    error.value = failure;
  } finally {
    busy.value = false;
  }
}

const sendCode = () => run(async () => {
  await props.requestCode(email.value);
  step.value = "code";
});

const resend = () => run(async () => {
  await props.requestCode(email.value);
  resent.value = true;
});

const finish = () => run(async () => {
  store.session = await props.complete({ email: email.value, code: code.value, password: password.value });
  router.push("/");
});
</script>

<template>
  <section class="auth">
    <h1>{{ title }}</h1>

    <form v-if="step === 'email'" @submit.prevent="sendCode">
      <label>Email <input v-model="email" type="email" autocomplete="email" required></label>
      <button class="button button-wide" :disabled="busy">Αποστολή κωδικού</button>
    </form>

    <form v-else @submit.prevent="finish">
      <p>{{ sentMessage }} <strong>{{ email }}</strong>.</p>
      <p class="muted">
        Ο κωδικός λήγει σε 15 λεπτά. Αν δεν έρθει, περιμένετε 15 λεπτά πριν ζητήσετε νέο.
      </p>
      <label>Κωδικός επιβεβαίωσης
        <input v-model="code" inputmode="numeric" autocomplete="one-time-code" maxlength="6" required>
      </label>
      <label>Κωδικός πρόσβασης
        <input v-model="password" type="password" autocomplete="new-password" required>
        <span class="hint">Τουλάχιστον 8 χαρακτήρες.</span>
      </label>
      <button class="button button-wide" :disabled="busy">{{ submitLabel }}</button>
      <button type="button" class="link-button" :disabled="busy" @click="resend">Στείλτε νέο κωδικό</button>
      <!-- Neutral, because the API answers alike for unknown emails and over the send limit. -->
      <p v-if="resent" class="muted">Το αίτημα για νέο κωδικό στάλθηκε.</p>
    </form>

    <p v-if="error" class="form-error">
      {{ errorMessage(error) }}
      <RouterLink v-if="error.code === 'email_taken'" to="/login">Σύνδεση</RouterLink>
    </p>
    <slot />
  </section>
</template>
