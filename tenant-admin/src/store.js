import { reactive } from "vue";

export const store = reactive({ slug: "" });

/**
 * Reads the store slug the admin host serves. Without it, sign-in pages ask for the slug.
 */
export async function loadStore() {
  // A host without the file may answer the app's HTML instead, which is not JSON.
  // A short timeout, since the app mounts only after this.
  const body = await fetch("/store.json", { signal: AbortSignal.timeout(3000) })
    .then((response) => response.ok && response.json())
    .catch(() => null);
  if (typeof body?.slug === "string") store.slug = body.slug.trim();
}
