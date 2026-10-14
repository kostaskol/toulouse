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
 * @param page [Object] optional `limit`, `after` and `filter`. Send the same filter with `after`.
 * @return [Object] `products`, `meta.next_cursor`, and `facets` on the first page
 */
export const listCategoryProducts = (slug, { limit, after, filter } = {}) =>
  request("GET", `categories/${encodeURIComponent(slug)}/products`, {
    query: { limit, after, ...filterQuery(filter) }
  });

/**
 * Searches products. An unfiltered query that names one category answers with that category instead, so the
 * storefront can open its page.
 *
 * @param query [String]
 * @param page [Object] optional `limit`, `after` and `filter`. Send the same filter with `after`.
 * @return [Object] `category`, or `products` with `meta.next_cursor`, `meta.match` (`exact` or `fuzzy`), and
 *   `facets` on the first page
 */
export const search = (query, { limit, after, filter } = {}) =>
  request("GET", `search/${encodeURIComponent(query)}`, { query: { limit, after, ...filterQuery(filter) } });

/**
 * Turns a filter into one URL path segment. The same filter gives the same segment whatever order it was picked
 * in, so each filtered page has one address for search engines.
 *
 * @param filter [Object] `categories`, `brands`, `price_min`, `price_max`, `options` and `available`, as the
 *   facets name them
 * @return [String] already percent-encoded
 */
export function filterPath(filter = {}) {
  const entries = [
    ...(filter.categories ?? []).map((slug) => ["category", slug]),
    ...(filter.brands ?? []).map((slug) => ["brand", slug]),
    ...Object.entries(filter.options ?? {}).flatMap(([key, values]) => values.map((value) => [`option.${key}`, value])),
    ...["price_min", "price_max"].filter((name) => filter[name] != null).map((name) => [name, String(filter[name])])
  ];
  if (filter.available) entries.push(["available", "true"]);
  const text = ([name, value]) => `${name}=${value}`;
  const sorted = entries.sort((a, b) => (text(a) < text(b) ? -1 : text(a) > text(b) ? 1 : 0));
  // A value picked twice must not give the same filter a second address.
  const unique = sorted.filter((entry, index) => index === 0 || text(entry) !== text(sorted[index - 1]));
  return new URLSearchParams(unique).toString();
}

/**
 * Reads a filter back from a segment that filterPath made.
 *
 * @param segment [String] as it appears in the URL, still percent-encoded
 * @return [Object]
 */
export function parseFilterPath(segment) {
  const filter = {};
  // A Map, so a key such as __proto__ stays a plain option key.
  const options = new Map();
  const add = (list, value) => [...(list ?? []), value];
  for (const [name, value] of new URLSearchParams(segment)) {
    if (name === "category") filter.categories = add(filter.categories, value);
    else if (name === "brand") filter.brands = add(filter.brands, value);
    else if (name === "price_min" || name === "price_max") filter[name] = Number(value);
    else if (name === "available") filter.available = value === "true";
    else if (name.startsWith("option.")) {
      const key = name.slice("option.".length);
      options.set(key, add(options.get(key), value));
    }
  }
  if (options.size) filter.options = Object.fromEntries(options);
  return filter;
}

/**
 * Flattens the category facet for a shop that shows only the categories with no children.
 *
 * @param categories [Array<Object>] the `facets.categories` tree
 * @return [Array<Object>]
 */
export const categoryLeaves = (categories) =>
  categories.flatMap((category) => (category.children.length ? categoryLeaves(category.children) : [category]));

function filterQuery(filter) {
  const { categories, brands, price_min, price_max, options = {}, available } = filter ?? {};
  const query = {
    "filter[categories][]": categories,
    "filter[brands][]": brands,
    "filter[price_min]": price_min,
    "filter[price_max]": price_max,
    "filter[available]": available ? "true" : null
  };
  for (const [key, values] of Object.entries(options ?? {})) query[`filter[options][${key}][]`] = values;
  return query;
}

async function request(method, path, { query = {}, body } = {}) {
  const url = new URL(path, BFF_URL);
  for (const [name, value] of Object.entries(query)) {
    for (const each of [value].flat()) if (each != null) url.searchParams.append(name, each);
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
