import { reactive, watch } from "vue";
import { shop } from "./shop.js";

export const SHOP_NAME = "Λινό";

export const store = reactive({ session: null, categories: [], cart: null, notice: null });

shop.onSignedOut(() => {
  store.session = null;
});

// Signing in moves the guest cart into the shopper's, and signing out leaves the guest with none.
watch(() => store.session, loadCart);

export async function loadStore() {
  const [session, categories] = await Promise.allSettled([shop.currentSession(), shop.listCategories()]);
  if (session.status === "fulfilled") signedIn(session.value);
  if (!store.session) loadCart();
  if (categories.status === "fulfilled") store.categories = categories.value.categories;
  for (const result of [session, categories]) if (result.status === "rejected") console.error(result.reason);
}

/**
 * Takes a new or restored session.
 *
 * @param session [Object, null]
 */
export function signedIn(session) {
  store.session = session;
  if (shop.hasWarning(session, "carts_merged")) {
    store.notice = "Τα προϊόντα που προσθέσατε πριν συνδεθείτε μπήκαν στο καλάθι μαζί με όσα είχατε ήδη.";
  }
}

export async function loadCart() {
  try {
    ({ cart: store.cart } = await shop.getCart());
  } catch (error) {
    console.error(error);
  }
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
