<script setup>
defineProps({ category: { type: Object, required: true } });
defineEmits(["edit", "remove", "add-child"]);
</script>

<template>
  <li>
    <div class="tree-row">
      <span class="tree-name">{{ category.name }} <span class="muted small">/{{ category.slug }}</span></span>
      <span class="muted small">θέση {{ category.position }}</span>
      <button class="button button-small" @click="$emit('add-child', category)">+ Υποκατηγορία</button>
      <button class="button button-small" @click="$emit('edit', category)">Επεξεργασία</button>
      <button class="button button-small button-danger" @click="$emit('remove', category)">Διαγραφή</button>
    </div>
    <ul v-if="category.children.length">
      <CategoryNode
        v-for="child in category.children" :key="child.id" :category="child"
        @edit="$emit('edit', $event)" @remove="$emit('remove', $event)" @add-child="$emit('add-child', $event)"
      />
    </ul>
  </li>
</template>
