<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { request } from "../api.js";
import { useAction } from "../action.js";
import { formatDateTime } from "../format.js";
import { IMPORT_STATUS_BADGES, IMPORT_STATUSES } from "../labels.js";
import { useList } from "../list.js";
import { baseErrors } from "../messages.js";
import FormErrors from "../components/FormErrors.vue";
import LoadMore from "../components/LoadMore.vue";

const router = useRouter();
const list = useList("/product_imports", "product_imports");
const file = ref(null);
const uploading = useAction();
const errors = computed(() => baseErrors(uploading.error.value, list.error.value));

onMounted(() => list.load());

/**
 * @param dryRun [Boolean]
 */
async function upload(dryRun) {
  let started;
  const done = await uploading.run(async () => {
    // Spreadsheet apps label CSV files with several types, and the API takes only text/csv.
    ({ product_import: started } = await request("POST", "/product_imports", {
      body: file.value, type: "text/csv", query: { dry_run: dryRun }
    }));
  });
  if (done) router.push(`/imports/${started.id}`);
}
</script>

<template>
  <div class="page-head"><h1>Εισαγωγή προϊόντων</h1></div>

  <section class="panel">
    <h2>Νέα εισαγωγή</h2>
    <p class="hint">
      Ανεβάστε αρχείο CSV σε UTF-8. Η «Δοκιμή» δείχνει τι θα άλλαζε χωρίς να αλλάξει τίποτα. Η «Εισαγωγή» αλλάζει
      τον κατάλογο.
    </p>
    <FormErrors :messages="errors" />
    <form class="form" @submit.prevent="upload(true)">
      <input type="file" accept=".csv,text/csv" required @change="file = $event.target.files[0] ?? null">
      <div class="form-actions">
        <button class="button button-primary" :disabled="uploading.busy.value || !file">Δοκιμή</button>
        <button type="button" class="button" :disabled="uploading.busy.value || !file" @click="upload(false)">
          Εισαγωγή
        </button>
      </div>
    </form>
  </section>

  <div class="table-wrap">
    <table>
      <thead><tr><th>Ξεκίνησε</th><th>Κατάσταση</th><th>Είδος</th><th>Τέλος</th><th></th></tr></thead>
      <tbody>
        <tr v-for="item in list.items.value" :key="item.id">
          <td class="nowrap">{{ formatDateTime(item.created_at) }}</td>
          <td>
            <span class="badge" :class="IMPORT_STATUS_BADGES[item.status]">{{ IMPORT_STATUSES[item.status] }}</span>
          </td>
          <td>{{ item.dry_run ? "Δοκιμή" : "Εισαγωγή" }}</td>
          <td class="nowrap muted">{{ formatDateTime(item.finished_at) }}</td>
          <td class="actions">
            <RouterLink :to="`/imports/${item.id}`" class="button button-small">Αποτέλεσμα</RouterLink>
          </td>
        </tr>
        <tr v-if="!list.busy.value && !list.items.value.length">
          <td colspan="5" class="empty">Καμία εισαγωγή ακόμα.</td>
        </tr>
      </tbody>
    </table>
  </div>
  <LoadMore :next="list.next.value" :busy="list.busy.value" @more="list.loadMore" />
</template>
