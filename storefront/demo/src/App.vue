<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { shop } from "./shop.js";
import { store, SHOP_NAME } from "./store.js";
import { errorMessage } from "./messages.js";
import CategoryMenu from "./components/CategoryMenu.vue";

const router = useRouter();
const signOutError = ref(null);

async function signOut() {
  signOutError.value = null;
  try {
    await shop.signOut();
  } catch (error) {
    signOutError.value = errorMessage(error);
    return;
  }
  store.session = null;
  router.push("/");
}
</script>

<template>
  <header class="site-header">
    <div class="container header-row">
      <RouterLink to="/" class="logo">{{ SHOP_NAME }}</RouterLink>
      <CategoryMenu :categories="store.categories" />
      <div class="account">
        <template v-if="store.session">
          <span class="account-email">{{ store.session.shopper.email }}</span>
          <button class="link-button" @click="signOut">Αποσύνδεση</button>
          <span v-if="signOutError" class="form-error">{{ signOutError }}</span>
        </template>
        <RouterLink v-else to="/login">Σύνδεση</RouterLink>
      </div>
    </div>
  </header>

  <main class="container">
    <RouterView v-slot="{ Component, route }">
      <Suspense>
        <component :is="Component" :key="route.fullPath" />
      </Suspense>
    </RouterView>
  </main>

  <footer class="site-footer">
    <div class="container">
      <p>{{ SHOP_NAME }} · Ρούχα και παπούτσια από λινό, βαμβάκι και δέρμα</p>
    </div>
  </footer>
</template>
