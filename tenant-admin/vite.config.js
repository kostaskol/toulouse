import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

export default defineConfig({
  plugins: [vue()],
  server: {
    host: true,
    // Development mail links point at this port.
    port: 5174,
    strictPort: true,
    // Production puts the same proxy in front of each admin host, so the staff cookie stays first-party.
    proxy: { "/admin": { target: process.env.API_PROXY_TARGET ?? "http://localhost:3000", changeOrigin: true } }
  }
});
