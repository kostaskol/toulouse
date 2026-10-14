// Undefined under node --test, where tests pass full paths against a stubbed fetch.
const BASE = import.meta.env?.VITE_API_URL ?? "";
const SIGNED_OUT_CODES = ["missing_session", "invalid_session"];

let signedOutHandler = () => {};

export class ApiError extends Error {
  /**
   * @param status [Number]
   * @param errors [Array<Object>] the API's errors array
   * @param retryAfter [Number, null] seconds, from Retry-After
   */
  constructor(status, errors, retryAfter = null) {
    super(errors[0]?.message ?? `Request failed with status ${status}`);
    this.status = status;
    this.errors = errors;
    this.code = errors[0]?.code;
    this.retryAfter = retryAfter;
  }
}

/**
 * Runs on any answer that says the staff session is gone.
 *
 * @param handler [Function]
 */
export function onSignedOut(handler) {
  signedOutHandler = handler;
}

/**
 * Calls an /admin endpoint and returns its parsed body.
 *
 * @param method [String]
 * @param path [String] below /admin
 * @param options [Object] `json` for a JSON body, or `body` with its `type`; `query` for the query string
 * @return [Object, null] null for an empty answer
 */
export async function request(method, path, { json, body, type, query } = {}) {
  const headers = {};
  if (json !== undefined) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(json);
  } else if (body !== undefined) {
    headers["Content-Type"] = type;
  }

  let response;
  try {
    response = await fetch(`${BASE}/admin${path}${queryString(query)}`, {
      method, headers, body, credentials: "include"
    });
  } catch {
    throw new ApiError(0, [{ code: "network", message: "The API could not be reached." }]);
  }

  const parsed = await response.json().catch(() => null);
  if (response.ok) return parsed;

  const errors = parsed?.errors ?? [{ code: "bad_response", message: `The API answered ${response.status}.` }];
  const retryAfter = Number(response.headers.get("Retry-After")) || null;
  const error = new ApiError(response.status, errors, retryAfter);
  if (SIGNED_OUT_CODES.includes(error.code)) signedOutHandler(error);
  throw error;
}

export const get = (path, query) => request("GET", path, { query });
export const post = (path, json, query) => request("POST", path, { json, query });
export const put = (path, json) => request("PUT", path, { json });
export const patch = (path, json) => request("PATCH", path, { json });
export const destroy = (path) => request("DELETE", path);

function queryString(query) {
  if (!query) return "";

  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== null && value !== "") params.set(key, value);
  }
  const text = params.toString();
  return text ? `?${text}` : "";
}
