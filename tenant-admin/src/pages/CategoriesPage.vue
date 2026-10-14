<script setup>
import { computed, onMounted, ref } from "vue";
import { destroy, patch, post } from "../api.js";
import { useAction } from "../action.js";
import { flatten, loadCategories } from "../categories.js";
import { baseErrors, formErrors } from "../messages.js";
import { notify } from "../notice.js";
import CategoryNode from "../components/CategoryNode.vue";
import FormErrors from "../components/FormErrors.vue";
import FormField from "../components/FormField.vue";

const FIELDS = ["name", "slug", "parent_id", "position"];
const blank = (parentId = null) => ({ id: null, name: "", slug: "", parent_id: parentId, position: 0 });

const tree = ref([]);
const form = ref(blank());
const loading = useAction();
const saving = useAction();
const removing = useAction();
const errors = computed(() => formErrors(saving.error.value, FIELDS));
const pageErrors = computed(() => baseErrors(loading.error.value, removing.error.value));
// A category cannot move below itself, so its own subtree is left out of the parents.
const parents = computed(() => flatten(tree.value).filter((category) => !inSubtree(category)));

onMounted(reload);

async function reload() {
  await loading.run(async () => (tree.value = await loadCategories()));
}

function inSubtree(category) {
  if (!form.value.id) return false;

  // Gone when the category being edited was just deleted.
  const own = flatten(tree.value).find((item) => item.id === form.value.id);
  return own ? flatten([own]).some((item) => item.id === category.id) : false;
}

function edit(category) {
  saving.error.value = null;
  form.value = { ...category };
}

function addChild(category) {
  saving.error.value = null;
  form.value = blank(category.id);
}

async function save() {
  const { id, name, slug, parent_id, position } = form.value;
  const body = { name, slug: slug || undefined, parent_id, position: Number(position) || 0 };
  const done = await saving.run(() => (id ? patch(`/categories/${id}`, body) : post("/categories", body)));
  if (!done) return;

  notify(id ? "Η κατηγορία αποθηκεύτηκε." : "Η κατηγορία προστέθηκε.");
  form.value = blank();
  reload();
}

async function remove(category) {
  if (!confirm(`Διαγραφή της κατηγορίας «${category.name}»;`)) return;

  if (!(await removing.run(() => destroy(`/categories/${category.id}`)))) return;

  if (form.value.id === category.id) form.value = blank();
  reload();
}
</script>

<template>
  <div class="page-head"><h1>Κατηγορίες</h1></div>

  <section class="panel">
    <h2>{{ form.id ? "Επεξεργασία κατηγορίας" : "Νέα κατηγορία" }}</h2>
    <FormErrors :messages="errors.base" />
    <form class="form" @submit.prevent="save">
      <div class="form-row">
        <FormField label="Όνομα" :error="errors.fields.name"><input v-model="form.name" required></FormField>
        <FormField label="Slug" hint="Κενό για αυτόματο." :error="errors.fields.slug">
          <input v-model="form.slug">
        </FormField>
        <FormField label="Γονική κατηγορία" :error="errors.fields.parent_id">
          <select v-model="form.parent_id">
            <option :value="null">Καμία (κορυφή)</option>
            <option v-for="parent in parents" :key="parent.id" :value="parent.id">{{ parent.label }}</option>
          </select>
        </FormField>
        <FormField label="Θέση" hint="Μικρότερη θέση, πιο πάνω." :error="errors.fields.position">
          <input v-model="form.position" type="number" step="1">
        </FormField>
      </div>
      <div class="form-actions">
        <button class="button button-primary" :disabled="saving.busy.value">
          {{ form.id ? "Αποθήκευση" : "Προσθήκη" }}
        </button>
        <button v-if="form.id || form.parent_id" type="button" class="button" @click="form = blank()">Άκυρο</button>
      </div>
    </form>
  </section>

  <FormErrors :messages="pageErrors" />
  <section class="panel">
    <ul v-if="tree.length" class="tree">
      <CategoryNode
        v-for="category in tree" :key="category.id" :category="category"
        @edit="edit" @remove="remove" @add-child="addChild"
      />
    </ul>
    <p v-else-if="!loading.busy.value" class="empty">Δεν υπάρχουν κατηγορίες.</p>
  </section>
</template>
