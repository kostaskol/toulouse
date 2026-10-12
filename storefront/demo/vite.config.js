import { defineConfig, loadEnv } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig(({ mode }) => {
  // The library loads from this URL at runtime, so a build without it ships a broken shop.
  if (!loadEnv(mode, import.meta.dirname).VITE_BFF_URL) throw new Error("VITE_BFF_URL is not set");

  return {
    plugins: [vue()],
    // The BFF allows one storefront origin, so the port must not drift.
    server: { host: true, port: 5173, strictPort: true }
  };
});
