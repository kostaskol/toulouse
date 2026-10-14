import { defineConfig, loadEnv } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig(({ mode }) => {
  // Every request goes to this origin, so a build without it cannot reach the API.
  if (!loadEnv(mode, import.meta.dirname).VITE_API_URL) throw new Error("VITE_API_URL is not set");

  return {
    plugins: [vue()],
    // The API admits one admin origin, so the port must not drift.
    server: { host: true, port: 5174, strictPort: true }
  };
});
