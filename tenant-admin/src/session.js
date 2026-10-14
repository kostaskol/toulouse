import { reactive } from "vue";
import { destroy, get } from "./api.js";

const SLUG_KEY = "store-slug";

export const session = reactive({ staff: null, tenant: null, loaded: false });

/**
 * @param body [Object, null] a session answer from the API
 */
export function setSession(body) {
  session.staff = body?.staff ?? null;
  session.tenant = body?.tenant ?? null;
}

export async function loadSession() {
  if (session.loaded) return;

  // Any failure means signed out here. The login form shows the real error on submit.
  setSession(await get("/session").catch(() => null));
  session.loaded = true;
}

export async function signOut() {
  await destroy("/session").catch(() => {});
  setSession(null);
}

/**
 * @param permission [String]
 * @return [Boolean]
 */
export const can = (permission) => session.staff?.permissions.includes(permission) ?? false;

// Storage can be blocked, and the slug is only a convenience.
export function rememberedSlug() {
  try {
    return localStorage.getItem(SLUG_KEY) ?? "";
  } catch {
    return "";
  }
}

/**
 * @param slug [String]
 */
export function rememberSlug(slug) {
  try {
    localStorage.setItem(SLUG_KEY, slug);
  } catch {
    // Nothing to do: the next login asks again.
  }
}
