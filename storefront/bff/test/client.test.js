import { beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import * as client from "../client.js";

// The library resolves paths against its own URL, which is the BFF in a browser.
const BFF_URL = new URL("../", import.meta.url);

let calls;
let replies;

globalThis.fetch = async (url, init) => {
  calls.push({ url: url.toString(), ...init });
  const reply = replies.shift();
  if (reply instanceof Error) throw reply;

  return new Response(reply.body ?? null, { status: reply.status ?? 200, headers: reply.headers });
};

const json = (status, body, headers = {}) => ({
  status,
  body: JSON.stringify(body),
  headers: { "content-type": "application/json", ...headers }
});
const failure = (status, code, headers) => json(status, { errors: [{ code, message: "" }] }, headers);

beforeEach(() => {
  calls = [];
  replies = [json(200, {})];
});

describe("requests", () => {
  test("sends the method, path, JSON body and cookies to the BFF", async () => {
    await client.signIn({ email: "shopper", password: "test-password" });

    const [call] = calls;
    assert.equal(call.url, new URL("session", BFF_URL).toString());
    assert.equal(call.method, "POST");
    assert.equal(call.credentials, "include");
    assert.equal(call.headers["content-type"], "application/json");
    assert.deepEqual(JSON.parse(call.body), { email: "shopper", password: "test-password" });
  });

  test("sends no body or content type on reads", async () => {
    await client.listCategories();

    assert.equal(calls[0].method, "GET");
    assert.equal(calls[0].body, undefined);
    assert.equal(calls[0].headers["content-type"], undefined);
  });

  test("puts page parameters in the query and leaves out the missing ones", async () => {
    await client.listCategoryProducts("a/b", { after: "cursor" });

    assert.equal(calls[0].url, new URL("categories/a%2Fb/products?after=cursor", BFF_URL).toString());
  });

  test("keeps a slash in a search query inside one path segment", async () => {
    await client.search("a/b");

    assert.equal(calls[0].url, new URL("search/a%2Fb", BFF_URL).toString());
  });

  test("answers null for an empty body", async () => {
    replies = [{ status: 202 }];

    assert.equal(await client.requestSignupCode("shopper"), null);
  });

  test("answers the parsed body", async () => {
    replies = [json(200, { product: { slug: "a" } })];

    assert.deepEqual(await client.getProduct("a"), { product: { slug: "a" } });
  });
});

describe("filters", () => {
  const filter = {
    categories: ["b", "a"],
    brands: ["c"],
    price_min: 100,
    price_max: 200,
    attributes: { "χρωμα": ["μαυρο", "a&b/c"] },
    available: true
  };

  test("sends a filter in the query", async () => {
    await client.search("q", { filter });

    const query = [...new URL(calls[0].url).searchParams];
    assert.deepEqual(query, [
      ["filter[categories][]", "b"],
      ["filter[categories][]", "a"],
      ["filter[brands][]", "c"],
      ["filter[price_min]", "100"],
      ["filter[price_max]", "200"],
      ["filter[available]", "true"],
      ["filter[attributes][χρωμα][]", "μαυρο"],
      ["filter[attributes][χρωμα][]", "a&b/c"]
    ]);
  });

  test("takes a null filter as none", async () => {
    await client.search("q", { filter: null });

    assert.equal(calls[0].url, new URL("search/q", BFF_URL).toString());
  });

  test("gives one path segment per filter, whatever the order", () => {
    const reordered = { ...filter, categories: ["a", "b"], attributes: { "χρωμα": ["a&b/c", "μαυρο"] } };

    assert.equal(client.filterPath(filter), client.filterPath(reordered));
    assert.equal(client.filterPath(filter), client.filterPath({ ...filter, brands: ["c", "c"] }));
    assert.doesNotMatch(client.filterPath(filter), /\//);
  });

  test("reads back the filter its path segment holds", () => {
    const read = client.parseFilterPath(client.filterPath(filter));

    assert.deepEqual(read, { ...filter, categories: ["a", "b"], attributes: { "χρωμα": ["a&b/c", "μαυρο"] } });
  });

  test("keeps an attribute key named like an object property", () => {
    const read = client.parseFilterPath("attribute.__proto__=a&attribute.constructor=b");

    assert.deepEqual(Object.entries(read.attributes), [["__proto__", ["a"]], ["constructor", ["b"]]]);
  });

  test("gives the leaves of the category facet", () => {
    const leaf = (slug) => ({ slug, children: [] });
    const tree = [{ slug: "a", children: [leaf("b"), { slug: "c", children: [leaf("d")] }] }, leaf("e")];

    assert.deepEqual(client.categoryLeaves(tree).map((category) => category.slug), ["b", "d", "e"]);
  });
});

describe("errors", () => {
  test("throws the first error's code with the status and Retry-After", async () => {
    replies = [failure(429, "too_many_attempts", { "retry-after": "30" })];

    await assert.rejects(client.signIn({}), {
      name: "ApiError", status: 429, code: "too_many_attempts", retryAfter: 30
    });
  });

  test("leaves retryAfter null without the header", async () => {
    replies = [failure(422, "invalid_email")];

    await assert.rejects(client.requestSignupCode(""), { code: "invalid_email", retryAfter: null });
  });

  test("throws bad_gateway when the BFF cannot be reached", async () => {
    replies = [new TypeError("fetch failed")];

    await assert.rejects(client.listProducts(), { status: 502, code: "bad_gateway" });
  });

  test("throws bad_gateway for a body that is not JSON", async () => {
    replies = [{ status: 200, body: "<html>" }];

    await assert.rejects(client.listProducts(), { code: "bad_gateway" });
  });

  test("throws bad_gateway for an error without the errors shape", async () => {
    replies = [json(500, {})];

    await assert.rejects(client.listProducts(), { status: 500, code: "bad_gateway" });
  });
});

describe("session", () => {
  test("answers the session when signed in", async () => {
    replies = [json(200, { shopper: { email: "shopper" } })];

    assert.deepEqual(await client.currentSession(), { shopper: { email: "shopper" } });
  });

  test("answers null when no session or a dropped one", async () => {
    replies = [failure(401, "missing_session"), failure(401, "invalid_session")];

    assert.equal(await client.currentSession(), null);
    assert.equal(await client.currentSession(), null);
  });

  test("throws other failures", async () => {
    replies = [failure(502, "bad_gateway")];

    await assert.rejects(client.currentSession(), { code: "bad_gateway" });
  });

  test("tells listeners when any request finds the session dropped", async () => {
    let signedOut = 0;
    const stop = client.onSignedOut(() => signedOut++);
    replies = [
      failure(401, "invalid_session"), failure(401, "missing_session"), failure(401, "invalid_credentials")
    ];

    await assert.rejects(client.listProducts(), { code: "invalid_session" });
    await assert.rejects(client.listProducts(), { code: "missing_session" });
    await assert.rejects(client.signIn({}), { code: "invalid_credentials" });
    stop();
    replies = [failure(401, "invalid_session")];
    await assert.rejects(client.listProducts());

    assert.equal(signedOut, 2);
  });
});

describe("sign out", () => {
  test("succeeds when the session is already gone", async () => {
    replies = [failure(401, "missing_session"), failure(401, "invalid_session")];

    await client.signOut();
    await client.signOut();
  });

  test("throws other failures", async () => {
    replies = [failure(502, "bad_gateway")];

    await assert.rejects(client.signOut(), { code: "bad_gateway" });
  });
});
