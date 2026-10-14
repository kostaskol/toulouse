<script setup>
import { computed, onMounted, ref } from "vue";
import { destroy, patch, post } from "../api.js";
import { useAction } from "../action.js";
import { useList } from "../list.js";
import { baseErrors, formErrors } from "../messages.js";
import { notify } from "../notice.js";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";
import LoadMore from "../components/LoadMore.vue";

const FIELDS = ["name", "slug"];

const list = useList("/brands", "brands");
const fresh = ref({ name: "", slug: "" });
const creating = useAction();
const createErrors = computed(() => formErrors(creating.error.value, FIELDS));
const draft = ref(null);
const saving = useAction();
const saveErrors = computed(() => formErrors(saving.error.value, FIELDS));
const removing = useAction();

onMounted(() => list.load());

async function create() {
  const { name, slug } = fresh.value;
  const done = await creating.run(() => post("/brands", { name, slug: slug || undefined }));
  if (!done) return;

  fresh.value = { name: "", slug: "" };
  notify("Η μάρκα προστέθηκε.");
  list.load();
}

function edit(brand) {
  saving.error.value = null;
  draft.value = { ...brand };
}

async function save() {
  const { id, name, slug } = draft.value;
  const done = await saving.run(async () => {
    const { brand } = await patch(`/brands/${id}`, { name, slug: slug || undefined });
    list.items.value = list.items.value.map((item) => (item.id === id ? brand : item));
  });
  if (!done) return;

  draft.value = null;
  notify("Η μάρκα αποθηκεύτηκε.");
}

async function remove(brand) {
  if (!confirm(`Διαγραφή της μάρκας «${brand.name}»;`)) return;

  const done = await removing.run(() => destroy(`/brands/${brand.id}`));
  if (done) list.items.value = list.items.value.filter((item) => item.id !== brand.id);
}
</script>

<template>
  <div class="page-head"><h1>Μάρκες</h1></div>

  <section class="panel">
    <h2>Νέα μάρκα</h2>
    <FormErrors :messages="createErrors.base" />
    <form class="inline-form" @submit.prevent="create">
      <FormField label="Όνομα" :error="createErrors.fields.name">
        <input v-model="fresh.name" required>
      </FormField>
      <FormField label="Slug" hint="Κενό για αυτόματο." :error="createErrors.fields.slug">
        <input v-model="fresh.slug">
      </FormField>
      <button class="button button-primary" :disabled="creating.busy.value">Προσθήκη</button>
    </form>
  </section>

  <FormErrors :messages="[...baseErrors(list.error.value, removing.error.value), ...saveErrors.base]" />
  <div class="table-wrap">
    <table>
      <thead><tr><th>Όνομα</th><th>Slug</th><th></th></tr></thead>
      <tbody>
        <tr v-for="brand in list.items.value" :key="brand.id">
          <template v-if="draft?.id === brand.id">
            <td>
              <FormField label="Όνομα" :error="saveErrors.fields.name"><input v-model="draft.name"></FormField>
            </td>
            <td>
              <FormField label="Slug" :error="saveErrors.fields.slug"><input v-model="draft.slug"></FormField>
            </td>
            <td class="actions">
              <button class="button button-primary button-small" :disabled="saving.busy.value" @click="save">
                Αποθήκευση
              </button>
              <button class="button button-small" @click="draft = null">Άκυρο</button>
            </td>
          </template>
          <template v-else>
            <td>{{ brand.name }}</td>
            <td class="muted">{{ brand.slug }}</td>
            <td class="actions">
              <button class="button button-small" @click="edit(brand)">Επεξεργασία</button>
              <button class="button button-small button-danger" @click="remove(brand)">Διαγραφή</button>
            </td>
          </template>
        </tr>
        <tr v-if="!list.busy.value && !list.items.value.length">
          <td colspan="3" class="empty">Δεν υπάρχουν μάρκες.</td>
        </tr>
      </tbody>
    </table>
  </div>
  <LoadMore :next="list.next.value" :busy="list.busy.value" @more="list.loadMore" />
</template>
