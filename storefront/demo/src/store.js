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
 * @param slug [String]
 * @param categories [Array<Object>]
 * @return [Object, undefined]
 */
export function findCategory(slug, categories = store.categories) {
  for (const category of categories) {
    if (category.slug === slug) return category;

    const child = findCategory(slug, category.children);
    if (child) return child;
  }
}
