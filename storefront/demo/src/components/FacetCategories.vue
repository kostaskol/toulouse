<script setup>
defineOptions({ name: "FacetCategories" });
defineProps({
  categories: { type: Array, required: true },
  picked: { type: Array, required: true }
});
defineEmits(["toggle"]);
</script>

<template>
  <ul class="facet-tree">
    <li v-for="category in categories" :key="category.id">
      <label class="facet-check">
        <input type="checkbox" :checked="picked.includes(category.slug)" @change="$emit('toggle', category.slug)" />
        {{ category.name }} <span class="muted">({{ category.count }})</span>
      </label>
      <FacetCategories
        v-if="category.children.length"
        :categories="category.children"
        :picked="picked"
        @toggle="$emit('toggle', $event)"
      />
    </li>
  </ul>
</template>
