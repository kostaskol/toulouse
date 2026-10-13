<script setup>
import { shop } from "../shop.js";
import { SHOP_NAME } from "../store.js";
import EmailCodeFlow from "../components/EmailCodeFlow.vue";

document.title = `Δημιουργία λογαριασμού · ${SHOP_NAME}`;
</script>

<template>
  <EmailCodeFlow title="Δημιουργία λογαριασμού" sent-message="Στείλαμε έναν εξαψήφιο κωδικό στο"
                 submit-label="Δημιουργία λογαριασμού" :request-code="shop.requestSignupCode"
                 :complete="shop.completeSignup">
    <p>Έχετε ήδη λογαριασμό; <RouterLink to="/login">Σύνδεση</RouterLink></p>
  </EmailCodeFlow>
</template>
