<script setup>
import { computed, onMounted, ref } from "vue";
import { destroy, get, patch, post } from "../api.js";
import { useAction } from "../action.js";
import { baseErrors, formErrors } from "../messages.js";
import { notify } from "../notice.js";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";

const FIELDS = ["name", "position", "facet", "mode"];
const MODES = { any: "Οποιαδήποτε τιμή", all: "Όλες οι τιμές" };
const blank = () => ({ id: null, name: "", position: 0, facet: false, mode: "any" });

const specifications = ref([]);
const form = ref(blank());
const loading = useAction();
const saving = useAction();
const removing = useAction();
const errors = computed(() => formErrors(saving.error.value, FIELDS));
const pageErrors = computed(() => baseErrors(loading.error.value, removing.error.value));

onMounted(reload);

async function reload() {
  await loading.run(async () => (specifications.value = (await get("/specifications")).specifications));
}

function edit(specification) {
  saving.error.value = null;
  form.value = { ...specification };
}

async function save() {
  const { id, name, position, facet, mode } = form.value;
  const body = { name, position: Number(position) || 0, facet, mode };
  const done = await saving.run(() => (id ? patch(`/specifications/${id}`, body) : post("/specifications", body)));
  if (!done) return;

  notify(id ? "Η προδιαγραφή αποθηκεύτηκε." : "Η προδιαγραφή προστέθηκε.");
  form.value = blank();
  reload();
}

async function remove(specification) {
  const question = `Διαγραφή της προδιαγραφής «${specification.name}»; ` +
    "Θα αφαιρεθεί από κάθε προϊόν και παραλλαγή που την έχει.";
  if (!confirm(question)) return;

  if (await removing.run(() => destroy(`/specifications/${specification.id}`))) reload();
}
</script>

<template>
  <div class="page-head"><h1>Προδιαγραφές</h1></div>

  <section class="panel">
    <h2>{{ form.id ? "Επεξεργασία προδιαγραφής" : "Νέα προδιαγραφή" }}</h2>
    <FormErrors :messages="errors.base" />
    <form class="form" @submit.prevent="save">
      <div class="form-row">
        <FormField label="Όνομα" :error="errors.fields.name"><input v-model="form.name" required></FormField>
        <FormField label="Θέση" :error="errors.fields.position">
          <input v-model="form.position" type="number" step="1">
        </FormField>
        <FormField
          label="Τρόπος φίλτρου" hint="Πώς συνδυάζονται οι τιμές όταν ο πελάτης διαλέγει πολλές."
          :error="errors.fields.mode"
        >
          <select v-model="form.mode">
            <option v-for="(label, mode) in MODES" :key="mode" :value="mode">{{ label }}</option>
          </select>
        </FormField>
      </div>
      <label class="check"><input v-model="form.facet" type="checkbox"> Φίλτρο στο κατάστημα</label>
      <div class="form-actions">
        <button class="button button-primary" :disabled="saving.busy.value">
          {{ form.id ? "Αποθήκευση" : "Προσθήκη" }}
        </button>
        <button v-if="form.id" type="button" class="button" @click="form = blank()">Άκυρο</button>
      </div>
    </form>
  </section>

  <FormErrors :messages="pageErrors" />
  <div class="table-wrap">
    <table>
      <thead><tr><th>Όνομα</th><th class="num">Θέση</th><th>Φίλτρο</th><th>Τρόπος</th><th></th></tr></thead>
      <tbody>
        <tr v-for="specification in specifications" :key="specification.id">
          <td>{{ specification.name }}</td>
          <td class="num">{{ specification.position }}</td>
          <td><span v-if="specification.facet" class="badge badge-blue">Φίλτρο</span></td>
          <td>{{ MODES[specification.mode] }}</td>
          <td class="actions">
            <button class="button button-small" @click="edit(specification)">Επεξεργασία</button>
            <button class="button button-small button-danger" @click="remove(specification)">Διαγραφή</button>
          </td>
        </tr>
        <tr v-if="!loading.busy.value && !specifications.length">
          <td colspan="5" class="empty">Δεν υπάρχουν προδιαγραφές.</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
