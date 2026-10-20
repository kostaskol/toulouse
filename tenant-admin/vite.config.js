import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// Production admin hosts serve this file per store. Unset leaves the slug field on the sign-in pages.
const storeSlug = {
  name: "store-slug",
  configureServer(server) {
    const slug = process.env.STORE_SLUG;
    if (!slug) return;
    server.middlewares.use("/store.json", (_request, response) => {
      response.setHeader("Content-Type", "application/json");
      response.end(JSON.stringify({ slug }));
    });
  }
};

export default defineConfig({
  plugins: [vue(), storeSlug],
  server: {
    host: true,
    // Development mail links point at this port.
    port: 5174,
    strictPort: true,
    // Production puts the same proxy in front of each admin host, so the staff cookie stays first-party.
    proxy: { "/admin": { target: process.env.API_PROXY_TARGET ?? "http://localhost:3000", changeOrigin: true } }
  }
});
