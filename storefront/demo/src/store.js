import { reactive } from "vue";
import { shop } from "./shop.js";

export const SHOP_NAME = "Λινό";

export const store = reactive({ session: null, categories: [] });

shop.onSignedOut(() => {
  store.session = null;
});

export async function loadStore() {
  const [session, categories] = await Promise.allSettled([shop.currentSession(), shop.listCategories()]);
  if (session.status === "fulfilled") store.session = session.value;
  if (categories.status === "fulfilled") store.categories = categories.value.categories;
  for (const result of [session, categories]) if (result.status === "rejected") console.error(result.reason);
}

/**
 * Lists the category and its ancestors, the top level first.
 *
 * @param slug [String]
 * @param categories [Array<Object>]
 * @return [Array<Object>] empty when no category has the slug
 */
export function categoryTrail(slug, categories = store.categories) {
  for (const category of categories) {
    if (category.slug === slug) return [category];

    const trail = categoryTrail(slug, category.children);
    if (trail.length) return [category, ...trail];
  }
  return [];
}
