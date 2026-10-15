import { createApp } from "vue";
import App from "./App.vue";
import { onSignedOut } from "./api.js";
import { router } from "./router.js";
import { session, setSession } from "./session.js";
import { loadStore } from "./store.js";
import "./style.css";

onSignedOut(() => {
  // The first session check answers this too. The route guard redirects then, with the page asked for.
  if (!session.loaded) return;

  setSession(null);
  const current = router.currentRoute.value;
  if (!current.meta.public) router.push({ path: "/login", query: { next: current.fullPath } });
});

await loadStore();
createApp(App).use(router).mount("#app");
