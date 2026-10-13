<script setup>
defineProps({ categories: { type: Array, required: true } });
</script>

<template>
  <nav class="menu">
    <div v-for="category in categories" :key="category.id" class="menu-item">
      <RouterLink :to="`/categories/${category.slug}`">{{ category.name }}</RouterLink>
      <div v-if="category.children.length" class="submenu">
        <RouterLink v-for="child in category.children" :key="child.id" :to="`/categories/${child.slug}`">
          {{ child.name }}
        </RouterLink>
      </div>
    </div>
  </nav>
</template>
