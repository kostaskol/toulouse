<script setup>
import { shop } from "../shop.js";
import { SHOP_NAME } from "../store.js";
import EmailCodeFlow from "../components/EmailCodeFlow.vue";

document.title = `Ξέχασα τον κωδικό · ${SHOP_NAME}`;
</script>

<template>
  <!-- The API answers alike for unknown emails, so the copy must not claim a code was sent. -->
  <EmailCodeFlow title="Ξέχασα τον κωδικό πρόσβασης"
                 sent-message="Αν υπάρχει λογαριασμός με αυτό το email, στείλαμε έναν εξαψήφιο κωδικό στο"
                 submit-label="Αλλαγή κωδικού και σύνδεση" :request-code="shop.requestPasswordResetCode"
                 :complete="shop.completePasswordReset">
    <p><RouterLink to="/login">Πίσω στη σύνδεση</RouterLink></p>
  </EmailCodeFlow>
</template>
