import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router.js";
import { loadStore } from "./store.js";
import "./style.css";

await loadStore();
createApp(App).use(router).mount("#app");
