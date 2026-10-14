<script setup>
import { computed } from "vue";
import { can, session } from "../session.js";

const SECTIONS = [];

const sections = computed(() => SECTIONS.filter((section) => !section.permission || can(section.permission)));
</script>

<template>
  <div class="page-head">
    <h1>{{ session.tenant.name }}</h1>
  </div>
  <div class="cards">
    <RouterLink v-for="section in sections" :key="section.to" :to="section.to" class="panel card-link">
      <strong>{{ section.label }}</strong>
      <span class="muted small">{{ section.text }}</span>
    </RouterLink>
  </div>
</template>
