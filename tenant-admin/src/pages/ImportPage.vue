<script setup>
import { computed, onMounted, onUnmounted, ref } from "vue";
import { get } from "../api.js";
import { useAction } from "../action.js";
import { formatDateTime } from "../format.js";
import { IMPORT_RESULTS, IMPORT_STATUS_BADGES, IMPORT_STATUSES, IMPORT_WARNINGS } from "../labels.js";
import { useList } from "../list.js";
import { baseErrors, errorMessage } from "../messages.js";
import FormErrors from "../components/FormErrors.vue";
import LoadMore from "../components/LoadMore.vue";

const POLL_MS = 2000;
const RUNNING = ["queued", "running"];
const RESULT_BADGES = { created: "badge-green", updated: "badge-blue", skipped: "", failed: "badge-red" };

const props = defineProps({ id: { type: String, required: true } });
const record = ref(null);
// Which entries to list: { result }, { warning } or { image_errors: true }.
const filter = ref({});
const loading = useAction();
const entries = useList(`/product_imports/${props.id}/entries`, "entries", () => filter.value);
const errors = computed(() => baseErrors(loading.error.value, entries.error.value));
const running = computed(() => RUNNING.includes(record.value?.status));

let timer;
let left = false;

onMounted(async () => {
  await refresh();
  entries.load();
});
onUnmounted(() => {
  left = true;
  clearTimeout(timer);
});

async function refresh() {
  await loading.run(async () => (record.value = (await get(`/product_imports/${props.id}`)).product_import));
  // An answer that lands after the page closed must not start the next poll.
  if (!running.value || left) return;

  timer = setTimeout(async () => {
    await refresh();
    // Once, when the run ends, so pages loaded with "more" stay while it runs.
    if (!running.value) entries.load();
  }, POLL_MS);
}

function show(next) {
  filter.value = JSON.stringify(next) === JSON.stringify(filter.value) ? {} : next;
  entries.load();
}

const isShown = (next) => JSON.stringify(next) === JSON.stringify(filter.value);
const warningLabel = (code) => IMPORT_WARNINGS[code] ?? "Προειδοποίηση";
</script>

<template>
  <div class="page-head">
    <div>
      <RouterLink to="/imports" class="back">← Εισαγωγές</RouterLink>
      <h1>{{ record?.dry_run ? "Δοκιμαστική εισαγωγή" : "Εισαγωγή" }}</h1>
    </div>
    <span v-if="record" class="badge" :class="IMPORT_STATUS_BADGES[record.status]">
      {{ IMPORT_STATUSES[record.status] }}
    </span>
  </div>
  <FormErrors :messages="errors" />

  <template v-if="record">
    <p class="muted small">
      Ξεκίνησε {{ formatDateTime(record.created_at) }}<template v-if="record.finished_at">,
      τελείωσε {{ formatDateTime(record.finished_at) }}</template>.
      <template v-if="running"> Η σελίδα ανανεώνεται μόνη της.</template>
    </p>
    <div v-if="record.dry_run && !running" class="alert alert-warn">
      Δοκιμή: δεν έγινε καμία αλλαγή. Ανεβάστε το αρχείο ξανά χωρίς δοκιμή για να γίνουν.
    </div>
    <div v-for="item in record.errors" :key="item.code" class="alert alert-error">{{ errorMessage(item) }}</div>

    <section class="panel">
      <h2>Σύνοψη</h2>
      <div class="stat-grid">
        <a
          v-for="(label, result) in IMPORT_RESULTS" :key="result" href="#" class="stat"
          :class="{ active: isShown({ result }) }" @click.prevent="show({ result })"
        >
          <div class="stat-value">{{ record.summary.results[result] ?? 0 }}</div>
          <div class="stat-label">{{ label }}</div>
        </a>
        <a
          v-for="(count, code) in record.summary.warnings" :key="code" href="#" class="stat"
          :class="{ active: isShown({ warning: code }) }" @click.prevent="show({ warning: code })"
        >
          <div class="stat-value">{{ count }}</div>
          <div class="stat-label">{{ warningLabel(code) }}</div>
        </a>
        <a
          href="#" class="stat" :class="{ active: isShown({ image_errors: true }) }"
          @click.prevent="show({ image_errors: true })"
        >
          <div class="stat-value">{{ record.summary.image_errors }}</div>
          <div class="stat-label">Με σφάλματα φωτογραφιών</div>
        </a>
        <div class="stat">
          <div class="stat-value">{{ record.images_pending }}</div>
          <div class="stat-label">Φωτογραφίες σε αναμονή</div>
        </div>
      </div>
    </section>

    <div class="table-wrap">
      <table>
        <thead><tr><th>Γραμμές</th><th>Handle</th><th>Αποτέλεσμα</th><th>Σημειώσεις</th></tr></thead>
        <tbody>
          <tr v-for="entry in entries.items.value" :key="entry.id">
            <td class="nowrap">{{ entry.rows.join(", ") }}</td>
            <td>
              <RouterLink v-if="entry.product_id && !record.dry_run" :to="`/products/${entry.product_id}`">
                {{ entry.handle }}
              </RouterLink>
              <template v-else>{{ entry.handle }}</template>
            </td>
            <td><span class="badge" :class="RESULT_BADGES[entry.result]">{{ IMPORT_RESULTS[entry.result] }}</span></td>
            <td>
              <ul v-if="entry.errors.length || entry.warnings.length || entry.image_errors.length" class="issues">
                <li v-for="(item, index) in entry.errors" :key="`e${index}`" class="field-error">
                  {{ item.field ? `${item.field}: ` : "" }}{{ errorMessage(item) }}
                </li>
                <li v-for="(item, index) in entry.warnings" :key="`w${index}`">
                  Γραμμή {{ item.row }}{{ item.field ? `, στήλη ${item.field}` : "" }}: {{ warningLabel(item.code) }}
                </li>
                <li v-for="(item, index) in entry.image_errors" :key="`i${index}`" class="field-error">
                  {{ item.url }}: {{ errorMessage(item) }}
                </li>
              </ul>
              <span v-if="entry.created_brands?.length" class="muted small">
                Νέες μάρκες: {{ entry.created_brands.join(", ") }}.
              </span>
              <span v-if="entry.created_categories?.length" class="muted small">
                Νέες κατηγορίες: {{ entry.created_categories.join(", ") }}.
              </span>
            </td>
          </tr>
          <tr v-if="!entries.busy.value && !entries.items.value.length">
            <td colspan="4" class="empty">Δεν υπάρχουν προϊόντα εδώ.</td>
          </tr>
        </tbody>
      </table>
    </div>
    <LoadMore :next="entries.next.value" :busy="entries.busy.value" @more="entries.loadMore" />
  </template>
</template>
