import { afterEach, test } from "node:test";
import assert from "node:assert/strict";
import { ApiError, destroy, onSignedOut, post, request } from "../src/api.js";

let calls = [];

function stub(status, body, headers = {}) {
  calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push({ url, init });
    return new Response(body === undefined ? null : JSON.stringify(body), { status, headers });
  };
}

afterEach(() => {
  delete globalThis.fetch;
  onSignedOut(() => {});
});

test("sends JSON and returns the body", async () => {
  stub(201, { brand: { id: "1" } });

  assert.deepEqual(await post("/brands", { name: "x" }), { brand: { id: "1" } });
  const [{ url, init }] = calls;
  assert.equal(url, "/admin/brands");
  assert.equal(init.method, "POST");
  assert.equal(init.headers["Content-Type"], "application/json");
  assert.equal(init.body, '{"name":"x"}');
});

test("sends a raw body with its own type and leaves out blank query values", async () => {
  stub(202, { product_import: {} });

  await request("POST", "/product_imports", { body: "a,b", type: "text/csv", query: { dry_run: false, x: "" } });
  const [{ url, init }] = calls;
  assert.equal(url, "/admin/product_imports?dry_run=false");
  assert.equal(init.headers["Content-Type"], "text/csv");
  assert.equal(init.body, "a,b");
});

test("returns null for an empty answer", async () => {
  stub(204);

  assert.equal(await destroy("/brands/1"), null);
});

test("throws the API's errors with Retry-After", async () => {
  const errors = [{ code: "too_many_attempts", message: "Too many" }];
  stub(429, { errors }, { "Retry-After": "120" });

  const error = await post("/session", {}).catch((caught) => caught);
  assert.ok(error instanceof ApiError);
  assert.equal(error.status, 429);
  assert.equal(error.code, "too_many_attempts");
  assert.deepEqual(error.errors, errors);
  assert.equal(error.retryAfter, 120);
});

test("calls the signed-out handler when the session is gone", async () => {
  let seen = null;
  onSignedOut((error) => (seen = error.code));
  stub(401, { errors: [{ code: "invalid_session", message: "gone" }] });

  await assert.rejects(post("/brands", {}));
  assert.equal(seen, "invalid_session");
});

test("turns a network failure or a body that is not JSON into an error", async () => {
  globalThis.fetch = async () => { throw new TypeError("offline"); };
  assert.equal((await post("/x", {}).catch((error) => error)).code, "network");

  globalThis.fetch = async () => new Response("<html>", { status: 502 });
  assert.equal((await post("/x", {}).catch((error) => error)).code, "bad_response");
});
