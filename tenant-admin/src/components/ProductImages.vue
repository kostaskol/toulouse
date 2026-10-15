<script setup>
import { computed, ref } from "vue";
import { destroy, patch, put, request } from "../api.js";
import { useAction } from "../action.js";
import { errorMessage } from "../messages.js";
import { notify } from "../notice.js";

// The types the API accepts.
const ACCEPT = "image/jpeg,image/png,image/webp";

const props = defineProps({ product: { type: Object, required: true } });
const emit = defineEmits(["changed"]);
const failures = ref([]);
const uploading = useAction();
const { busy, error, run } = useAction();
// An order sent mid-upload would miss the new images, and the API refuses it.
const locked = computed(() => uploading.busy.value || busy.value);
// The tile being dragged and the one under it, by index.
const dragged = ref(null);
const target = ref(null);
const path = () => `/products/${props.product.id}/images`;

async function upload(event) {
  const files = [...event.target.files];
  event.target.value = "";
  failures.value = [];
  await uploading.run(async () => {
    for (const file of files) {
      // One at a time, so the images keep the order they were picked in.
      await request("POST", path(), { body: file, type: file.type })
        .catch((caught) => failures.value.push(`${file.name}: ${errorMessage(caught)}`));
    }
  });
  if (failures.value.length < files.length) notify("Οι φωτογραφίες ανέβηκαν.");
  emit("changed");
}

async function saveAlt(image, alt) {
  if (alt === (image.alt ?? "")) return;

  let saved;
  if (!(await run(async () => ({ image: saved } = await patch(`${path()}/${image.id}`, { alt }))))) return;

  // In place rather than a reload, which would reset another alt input being typed in.
  image.alt = saved.alt;
  notify("Η περιγραφή αποθηκεύτηκε.");
}

async function move(from, to) {
  if (from === to) return;

  const ids = props.product.images.map((image) => image.id);
  const [id] = ids.splice(from, 1);
  ids.splice(to, 0, id);
  if (await run(() => put(`${path()}/order`, { image_ids: ids }))) emit("changed");
}

// Moving onto the tile's own picture or input also fires dragleave, which would make the outline blink.
function leave(event) {
  if (!event.currentTarget.contains(event.relatedTarget)) target.value = null;
}

function drop(index) {
  const from = dragged.value;
  dragged.value = null;
  target.value = null;
  if (from !== null && !locked.value) move(from, index);
}

async function remove(image) {
  if (!confirm("Διαγραφή της φωτογραφίας;")) return;

  if (await run(() => destroy(`${path()}/${image.id}`))) emit("changed");
}
</script>

<template>
  <section class="panel">
    <div class="panel-head">
      <h2>Φωτογραφίες</h2>
      <label class="button button-small">
        {{ uploading.busy.value ? "Ανέβασμα…" : "+ Φωτογραφίες" }}
        <input
          type="file" class="visually-hidden" :accept="ACCEPT" multiple :disabled="uploading.busy.value"
          @change="upload"
        >
      </label>
    </div>
    <div v-for="message in failures" :key="message" class="alert alert-error">{{ message }}</div>
    <div v-if="error" class="alert alert-error">{{ errorMessage(error) }}</div>
    <p v-if="product.images.length > 1" class="hint">Σύρετε μια φωτογραφία για να αλλάξετε τη σειρά.</p>
    <div v-if="product.images.length" class="images">
      <div
        v-for="(image, index) in product.images" :key="image.id" class="image-tile"
        :class="{ dragging: dragged === index, 'drop-target': target === index && dragged !== index }"
        @dragover.prevent="dragged !== null && (target = index)" @dragleave="leave"
        @drop.prevent="drop(index)"
      >
        <!-- Only the picture drags, so the alt input still selects text. -->
        <img
          :src="image.sizes[0]?.url ?? image.url" :alt="image.alt ?? ''" :draggable="!locked"
          @dragstart="dragged = index" @dragend="dragged = target = null"
        >
        <div class="image-body">
          <input :value="image.alt" placeholder="Περιγραφή" @change="saveAlt(image, $event.target.value)">
          <div class="image-actions">
            <button
              class="button button-small" aria-label="Μετακίνηση αριστερά" :disabled="locked || index === 0"
              @click="move(index, index - 1)"
            >
              ←
            </button>
            <button
              class="button button-small" aria-label="Μετακίνηση δεξιά"
              :disabled="locked || index === product.images.length - 1" @click="move(index, index + 1)"
            >
              →
            </button>
            <button class="button button-small button-danger" :disabled="locked" @click="remove(image)">
              Διαγραφή
            </button>
          </div>
        </div>
      </div>
    </div>
    <p v-else class="muted">Δεν υπάρχουν φωτογραφίες. Δεκτά αρχεία: JPEG, PNG, WebP.</p>
  </section>
</template>
