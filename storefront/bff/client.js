// The BFF serves this file, so the file's own URL is the BFF's address.
const BFF_URL = new URL("./", import.meta.url);

const SIGNED_OUT_CODES = new Set(["missing_session", "invalid_session"]);
const BAD_GATEWAY = { code: "bad_gateway", message: "The storefront server did not answer." };

const signedOutListeners = new Set();

export class ApiError extends Error {
  /**
   * @param status [Number]
   * @param errors [Array<Object>] each with `code` and `message`
   * @param retryAfter [Number, null] seconds
   */
  constructor(status, errors, retryAfter = null) {
    super(errors[0].message);
    this.name = "ApiError";
    this.status = status;
    this.code = errors[0].code;
    this.errors = errors;
    this.retryAfter = retryAfter;
  }
}

/**
 * Calls the listener whenever a request finds the session gone.
 *
 * @param listener [Function]
 * @return [Function] removes the listener
 */
export function onSignedOut(listener) {
  signedOutListeners.add(listener);
  return () => signedOutListeners.delete(listener);
}

/**
 * @param details [Object] `email` and `password`
 * @return [Object] `shopper` and `expires_at`
 */
export const signIn = ({ email, password }) => request("POST", "session", { body: { email, password } });

// A session that is already gone counts as signed out.
export async function signOut() {
  try {
    await request("DELETE", "session");
  } catch (error) {
    if (!(error instanceof ApiError && SIGNED_OUT_CODES.has(error.code))) throw error;
  }
}

/**
 * @return [Object, null] `shopper` and `expires_at`, or null when signed out
 */
export async function currentSession() {
  try {
    return await request("GET", "session");
  } catch (error) {
    if (error instanceof ApiError && SIGNED_OUT_CODES.has(error.code)) return null;
    throw error;
  }
}

/**
 * Mails a signup code.
 *
 * @param email [String]
 */
export const requestSignupCode = (email) => request("POST", "signup", { body: { email } });

/**
 * Creates the account and signs the shopper in.
 *
 * @param details [Object] `email`, `code` and `password`
 * @return [Object] `shopper` and `expires_at`
 */
export const completeSignup = ({ email, code, password }) =>
  request("PUT", "signup", { body: { email, code, password } });

/**
 * Mails a reset code if an account exists for the email.
 *
 * @param email [String]
 */
export const requestPasswordResetCode = (email) => request("POST", "password_reset", { body: { email } });

/**
 * Sets the new password and signs the shopper in.
 *
 * @param details [Object] `email`, `code` and `password`
 * @return [Object] `shopper` and `expires_at`
 */
export const completePasswordReset = ({ email, code, password }) =>
  request("PUT", "password_reset", { body: { email, code, password } });

/**
 * @param page [Object] optional `limit` and `after`
 * @return [Object] `products` and `meta.next_cursor`
 */
export const listProducts = ({ limit, after } = {}) => request("GET", "products", { query: { limit, after } });

/**
 * @param slug [String]
 * @return [Object] `product`
 */
export const getProduct = (slug) => request("GET", `products/${encodeURIComponent(slug)}`);

/**
 * @return [Object] `categories`, as a tree
 */
export const listCategories = () => request("GET", "categories");

/**
 * Lists the products of a category and of every category below it.
 *
 * @param slug [String]
 * @param page [Object] optional `limit` and `after`
 * @return [Object] `products` and `meta.next_cursor`
 */
export const listCategoryProducts = (slug, { limit, after } = {}) =>
  request("GET", `categories/${encodeURIComponent(slug)}/products`, { query: { limit, after } });

/**
 * Searches products. A query that names one category answers with that category instead, so the storefront can
 * open its page.
 *
 * @param query [String]
 * @param page [Object] optional `limit` and `after`
 * @return [Object] `category`, or `products` with `meta.next_cursor` and `meta.match` (`exact` or `fuzzy`)
 */
export const search = (query, { limit, after } = {}) =>
  request("GET", `search/${encodeURIComponent(query)}`, { query: { limit, after } });

async function request(method, path, { query = {}, body } = {}) {
  const url = new URL(path, BFF_URL);
  for (const [name, value] of Object.entries(query)) {
    if (value != null) url.searchParams.set(name, value);
  }

  const headers = { accept: "application/json" };
  if (body) headers["content-type"] = "application/json";

  let response;
  let data;
  try {
    response = await fetch(url, { method, headers, credentials: "include", body: body && JSON.stringify(body) });
    const text = await response.text();
    data = text ? JSON.parse(text) : null;
  } catch {
    throw new ApiError(502, [BAD_GATEWAY]);
  }

  if (response.ok) return data;

  const errors = Array.isArray(data?.errors) && data.errors.length ? data.errors : [BAD_GATEWAY];
  const retryAfter = response.headers.has("retry-after") ? Number(response.headers.get("retry-after")) : null;
  const error = new ApiError(response.status, errors, retryAfter);
  if (SIGNED_OUT_CODES.has(error.code)) signedOutListeners.forEach((listener) => listener());
  throw error;
}
