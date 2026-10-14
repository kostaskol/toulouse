<script setup>
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ROLES } from "./labels.js";
import { errorMessage } from "./messages.js";
import { notice } from "./notice.js";
import { can, session, signOut } from "./session.js";

const NAV = [
  { to: "/", label: "Αρχική" },
  { to: "/products", label: "Προϊόντα" },
  { to: "/imports", label: "Εισαγωγή προϊόντων" },
  { to: "/brands", label: "Μάρκες" },
  { to: "/categories", label: "Κατηγορίες" },
  { to: "/specifications", label: "Προδιαγραφές" },
  { to: "/staff", label: "Ομάδα", permission: "manage_staff" }
];

const route = useRoute();
const router = useRouter();
const nav = computed(() => NAV.filter((item) => !item.permission || can(item.permission)));
const suspended = computed(() => session.tenant?.status === "suspended");

async function logOut() {
  await signOut();
  router.push("/login");
}
</script>

<template>
  <div v-if="route.meta.public" class="auth-page">
    <div class="auth-card"><RouterView /></div>
  </div>
  <div v-else-if="session.staff" class="shell">
    <aside class="sidebar">
      <div class="store-name">
        {{ session.tenant.name }}
        <small>Διαχείριση καταστήματος</small>
      </div>
      <nav class="nav">
        <RouterLink v-for="item in nav" :key="item.to" :to="item.to">{{ item.label }}</RouterLink>
      </nav>
      <div class="me">
        <span class="me-email">
          {{ session.staff.email }}<br><span class="small">{{ ROLES[session.staff.role] }}</span>
        </span>
        <button class="button button-small" @click="logOut">Αποσύνδεση</button>
      </div>
    </aside>
    <main class="main">
      <div v-if="suspended" class="alert alert-warn">{{ errorMessage({ code: "tenant_suspended" }) }}</div>
      <RouterView :key="route.path" />
    </main>
  </div>
  <div v-if="notice" class="toast" role="status">{{ notice }}</div>
</template>
