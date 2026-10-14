<script setup>
import { computed, onMounted, ref } from "vue";
import { destroy, post } from "../api.js";
import { useAction } from "../action.js";
import { ROLES, STAFF_STATUSES } from "../labels.js";
import { useList } from "../list.js";
import { baseErrors, formErrors } from "../messages.js";
import { notify } from "../notice.js";
import { session } from "../session.js";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";
import LoadMore from "../components/LoadMore.vue";

const list = useList("/staff", "staff");
const email = ref("");
const inviting = useAction();
const inviteErrors = computed(() => formErrors(inviting.error.value, ["email"]));
const acting = useAction();
const pageErrors = computed(() => baseErrors(list.error.value, acting.error.value));

onMounted(() => list.load());

async function invite() {
  if (await inviting.run(() => send(email.value))) email.value = "";
}

async function resend(member) {
  await acting.run(() => send(member.email));
}

async function send(address) {
  const { staff } = await post("/staff", { email: address });
  notify(`Στάλθηκε πρόσκληση στο ${staff.email}.`);
  list.load();
}

async function remove(member) {
  const question = member.status === "pending"
    ? `Ακύρωση της πρόσκλησης του ${member.email};`
    : `Αφαίρεση του ${member.email} από το κατάστημα; Θα αποσυνδεθεί αμέσως.`;
  if (!confirm(question)) return;

  if (await acting.run(() => destroy(`/staff/${member.id}`))) {
    list.items.value = list.items.value.filter((item) => item.id !== member.id);
  }
}
</script>

<template>
  <div class="page-head"><h1>Ομάδα</h1></div>

  <section class="panel">
    <h2>Πρόσκληση μέλους</h2>
    <p class="hint">Το νέο μέλος παίρνει email με σύνδεσμο για να ορίσει κωδικό.</p>
    <FormErrors :messages="inviteErrors.base" />
    <form class="inline-form" @submit.prevent="invite">
      <FormField label="Email" :error="inviteErrors.fields.email">
        <input v-model="email" type="email" required>
      </FormField>
      <button class="button button-primary" :disabled="inviting.busy.value">Αποστολή πρόσκλησης</button>
    </form>
  </section>

  <FormErrors :messages="pageErrors" />
  <div class="table-wrap">
    <table>
      <thead><tr><th>Email</th><th>Ρόλος</th><th>Κατάσταση</th><th></th></tr></thead>
      <tbody>
        <tr v-for="member in list.items.value" :key="member.id">
          <td>{{ member.email }} <span v-if="member.id === session.staff.id" class="muted small">(εσείς)</span></td>
          <td>{{ ROLES[member.role] }}</td>
          <td>
            <span class="badge" :class="member.status === 'active' ? 'badge-green' : 'badge-yellow'">
              {{ STAFF_STATUSES[member.status] }}
            </span>
          </td>
          <td class="actions">
            <template v-if="member.status === 'pending'">
              <button class="button button-small" :disabled="acting.busy.value" @click="resend(member)">
                Νέα πρόσκληση
              </button>
              <button class="button button-small button-danger" @click="remove(member)">Ακύρωση πρόσκλησης</button>
            </template>
            <button
              v-else-if="member.id !== session.staff.id" class="button button-small button-danger"
              @click="remove(member)"
            >
              Αφαίρεση
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
  <LoadMore :next="list.next.value" :busy="list.busy.value" @more="list.loadMore" />
</template>
