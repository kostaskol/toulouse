import { after, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import http from "node:http";
import type { AddressInfo } from "node:net";
import { createBff, SESSION_COOKIE, type Config } from "../server.ts";

type Recorded = { method: string; url: string; headers: http.IncomingHttpHeaders; body: string };
type Reply = { status: number; headers?: Record<string, string>; body?: string; cutOff?: boolean };
type CallOptions = { method?: string; headers?: Record<string, string>; body?: string };

const API_VERSION = "v1";
const API_KEY = "test-api-key";
const STOREFRONT_ORIGIN = "http://storefront.localhost";
const OTHER_ORIGIN = "http://other.localhost";
const SESSION_TOKEN = "test-session-token";

let recorded: Recorded | undefined;
let reply: Reply;

const upstream = http.createServer(async (req, res) => {
  let body = "";
  for await (const chunk of req) body += chunk;
  recorded = { method: req.method!, url: req.url!, headers: req.headers, body };
  if (!reply.cutOff) return res.writeHead(reply.status, reply.headers).end(reply.body);

  res.writeHead(reply.status, { ...reply.headers, "content-length": "100" }).write("{");
  setImmediate(() => res.destroy());
});

const servers: http.Server[] = [upstream];

async function listen(server: http.Server) {
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  return (server.address() as AddressInfo).port;
}

async function startBff(overrides: Partial<Config> = {}) {
  const bff = createBff({
    toulouseUrl: `http://127.0.0.1:${(upstream.address() as AddressInfo).port}`,
    apiVersion: API_VERSION,
    apiKey: API_KEY,
    storefrontOrigin: STOREFRONT_ORIGIN,
    trustProxy: false,
    ...overrides
  });
  servers.push(bff);
  return listen(bff);
}

// http.request keeps the raw path, where fetch would resolve dot segments before sending.
function call(port: number, path: string, options: CallOptions = {}) {
  return new Promise<{ status: number; headers: http.IncomingHttpHeaders; body: string }>((resolve, reject) => {
    const { method = "GET", headers, body } = options;
    const req = http.request({ port, host: "127.0.0.1", path, method, headers });
    req.on("error", reject);
    req.on("response", async (res) => {
      let body = "";
      for await (const chunk of res) body += chunk;
      resolve({ status: res.statusCode!, headers: res.headers, body });
    });
    req.end(body);
  });
}

const JSON_HEADERS = { "content-type": "application/json" };

let port: number;

before(async () => {
  await listen(upstream);
  port = await startBff();
});

after(() => servers.forEach((server) => server.close()));

beforeEach(() => {
  recorded = undefined;
  reply = { status: 200, headers: JSON_HEADERS, body: JSON.stringify({}) };
});

describe("forwarding", () => {
  test("maps the path under the configured version and keeps method, query and body", async () => {
    const body = JSON.stringify({ email: "shopper" });

    await call(port, "/signup?a=1", { method: "POST", headers: { ...JSON_HEADERS, origin: STOREFRONT_ORIGIN }, body });

    assert.equal(recorded?.method, "POST");
    assert.equal(recorded?.url, `/${API_VERSION}/storefront/signup?a=1`);
    assert.equal(recorded?.body, body);
    assert.equal(recorded?.headers["content-type"], "application/json");
  });

  test("keeps dot segments inside the storefront prefix", async () => {
    for (const path of ["/../admin/products", "/%2e%2e/admin/products", "/products/%2E%2e/%2e%2e/admin"]) {
      await call(port, path);

      assert.ok(recorded?.url.startsWith(`/${API_VERSION}/storefront/`), `${path} reached ${recorded?.url}`);
    }
  });

  test("replaces credentials the browser sends and forwards no other headers", async () => {
    await call(port, "/products", {
      headers: { "x-api-key": "forged", "x-shopper-ip": "forged", authorization: "Bearer forged", "x-other": "1" }
    });

    assert.equal(recorded?.headers["x-api-key"], API_KEY);
    assert.equal(recorded?.headers["x-shopper-ip"], "127.0.0.1");
    assert.equal(recorded?.headers.authorization, undefined);
    assert.equal(recorded?.headers["x-other"], undefined);
  });

  test("sends the session cookie as a Bearer token and drops the cookie", async () => {
    await call(port, "/session", { headers: { cookie: `other=1; ${SESSION_COOKIE}=${SESSION_TOKEN}` } });

    assert.equal(recorded?.headers.authorization, `Bearer ${SESSION_TOKEN}`);
    assert.equal(recorded?.headers.cookie, undefined);
  });

  test("takes the shopper IP from the last forwarded entry behind a trusted proxy", async () => {
    const proxied = await startBff({ trustProxy: true });

    await call(proxied, "/products", { headers: { "x-forwarded-for": "forged, 192.0.2.1" } });

    assert.equal(recorded?.headers["x-shopper-ip"], "192.0.2.1");
  });

  test("ignores forwarded entries without a trusted proxy", async () => {
    await call(port, "/products", { headers: { "x-forwarded-for": "192.0.2.1" } });

    assert.equal(recorded?.headers["x-shopper-ip"], "127.0.0.1");
  });

  test("passes the status, body and Retry-After through", async () => {
    reply = { status: 429, headers: { ...JSON_HEADERS, "retry-after": "30" }, body: JSON.stringify({ errors: [] }) };

    const res = await call(port, "/products");

    assert.equal(res.status, 429);
    assert.equal(res.headers["retry-after"], "30");
    assert.equal(res.body, reply.body);
  });

  test("keeps Vary: Origin next to the API's Vary and drops its Location", async () => {
    reply = { status: 200, headers: { ...JSON_HEADERS, vary: "Accept", location: "http://api.internal/" }, body: "{}" };

    const res = await call(port, "/products", { headers: { origin: STOREFRONT_ORIGIN } });

    assert.deepEqual(res.headers.vary?.split(", ").sort(), ["Accept", "Origin"]);
    assert.equal(res.headers.location, undefined);
  });

  test("sends none of the API's headers when its body breaks off", async () => {
    reply = { status: 200, headers: { ...JSON_HEADERS, "cache-control": "max-age=60" }, cutOff: true };

    const res = await call(port, "/products");

    assert.equal(res.status, 502);
    assert.equal(res.headers["cache-control"], undefined);
  });

  test("answers bad_gateway when the API is down", async () => {
    const closed = http.createServer();
    const closedPort = await listen(closed);
    closed.close();
    const down = await startBff({ toulouseUrl: `http://127.0.0.1:${closedPort}` });

    const res = await call(down, "/products");

    assert.equal(res.status, 502);
    assert.equal(JSON.parse(res.body).errors[0].code, "bad_gateway");
  });
});

describe("session cookie", () => {
  test("moves a new session token into the cookie and out of the body", async () => {
    const expiresAt = new Date(Date.now() + 60_000);
    reply = {
      status: 201,
      headers: JSON_HEADERS,
      body: JSON.stringify({ token: SESSION_TOKEN, shopper: { email: "shopper" }, expires_at: expiresAt.toISOString() })
    };

    const res = await call(port, "/session", { method: "POST", headers: { origin: STOREFRONT_ORIGIN } });
    const cookie = res.headers["set-cookie"]?.[0] ?? "";

    assert.ok(cookie.startsWith(`${SESSION_COOKIE}=${SESSION_TOKEN};`));
    for (const attribute of ["Path=/", "Secure", "HttpOnly", "SameSite=Lax", `Expires=${expiresAt.toUTCString()}`]) {
      assert.ok(cookie.includes(attribute), `missing ${attribute}`);
    }
    assert.deepEqual(JSON.parse(res.body), { shopper: { email: "shopper" }, expires_at: expiresAt.toISOString() });
  });

  test("sets the cookie for a redeemed handoff", async () => {
    const expiresAt = new Date(Date.now() + 60_000).toISOString();
    const body = JSON.stringify({ token: SESSION_TOKEN, expires_at: expiresAt });
    reply = { status: 201, headers: JSON_HEADERS, body };

    const res = await call(port, "/handoff", { method: "POST", headers: { origin: STOREFRONT_ORIGIN } });

    assert.ok(res.headers["set-cookie"]?.[0]?.startsWith(`${SESSION_COOKIE}=${SESSION_TOKEN};`));
    assert.ok(!res.body.includes(SESSION_TOKEN));
  });

  test("treats a trailing slash as the same session route", async () => {
    const expiresAt = new Date(Date.now() + 60_000).toISOString();
    const body = JSON.stringify({ token: SESSION_TOKEN, expires_at: expiresAt });
    reply = { status: 201, headers: JSON_HEADERS, body };

    const res = await call(port, "/session/", { method: "POST", headers: { origin: STOREFRONT_ORIGIN } });

    assert.equal(recorded?.url, `/${API_VERSION}/storefront/session`);
    assert.ok(res.headers["set-cookie"]?.[0]?.startsWith(`${SESSION_COOKIE}=${SESSION_TOKEN};`));
    assert.ok(!res.body.includes(SESSION_TOKEN));
  });

  test("passes a token from other routes through untouched", async () => {
    reply = { status: 200, headers: JSON_HEADERS, body: JSON.stringify({ token: SESSION_TOKEN }) };

    const res = await call(port, "/products");

    assert.equal(res.headers["set-cookie"], undefined);
    assert.equal(res.body, reply.body);
  });

  test("fails without setting a cookie when a new session has no expiry", async () => {
    reply = { status: 201, headers: JSON_HEADERS, body: JSON.stringify({ token: SESSION_TOKEN }) };

    const res = await call(port, "/session", { method: "POST", headers: { origin: STOREFRONT_ORIGIN } });

    assert.equal(res.status, 500);
    assert.equal(res.headers["set-cookie"], undefined);
    assert.ok(!res.body.includes(SESSION_TOKEN));
  });

  test("clears the cookie on log out", async () => {
    reply = { status: 204 };

    const res = await call(port, "/session", { method: "DELETE", headers: { origin: STOREFRONT_ORIGIN } });

    assert.match(res.headers["set-cookie"]?.[0] ?? "", new RegExp(`^${SESSION_COOKIE}=;.*Expires=Thu, 01 Jan 1970`));
  });

  test("clears the cookie on invalid_session and passes the error on", async () => {
    const body = JSON.stringify({ errors: [{ code: "invalid_session", message: "" }] });
    reply = { status: 401, headers: JSON_HEADERS, body };

    const res = await call(port, "/session");

    assert.equal(res.status, 401);
    assert.match(res.headers["set-cookie"]?.[0] ?? "", new RegExp(`^${SESSION_COOKIE}=;`));
    assert.equal(res.body, reply.body);
  });

  test("leaves the cookie alone on other errors", async () => {
    const body = JSON.stringify({ errors: [{ code: "invalid_credentials", message: "" }] });
    reply = { status: 401, headers: JSON_HEADERS, body };

    const res = await call(port, "/session", { method: "POST", headers: { origin: STOREFRONT_ORIGIN } });

    assert.equal(res.headers["set-cookie"], undefined);
  });
});

describe("origin", () => {
  test("answers the preflight for the storefront origin", async () => {
    const res = await call(port, "/session", { method: "OPTIONS", headers: { origin: STOREFRONT_ORIGIN } });

    assert.equal(res.status, 204);
    assert.equal(res.headers["access-control-allow-origin"], STOREFRONT_ORIGIN);
    assert.equal(res.headers["access-control-allow-credentials"], "true");
    assert.equal(recorded, undefined);
  });

  test("grants no CORS access to another origin", async () => {
    const res = await call(port, "/products", { headers: { origin: OTHER_ORIGIN } });

    assert.equal(res.headers["access-control-allow-origin"], undefined);
  });

  test("rejects state-changing requests from another origin or none", async () => {
    for (const headers of [{ origin: OTHER_ORIGIN }, {}] as Record<string, string>[]) {
      const res = await call(port, "/session", { method: "POST", headers });

      assert.equal(res.status, 403);
      assert.equal(JSON.parse(res.body).errors[0].code, "forbidden_origin");
      assert.equal(recorded, undefined);
    }
  });
});

describe("browser library", () => {
  test("serves the library to the storefront without calling the API", async () => {
    const res = await call(port, "/client.js", { headers: { origin: STOREFRONT_ORIGIN } });

    assert.equal(res.status, 200);
    assert.equal(res.headers["content-type"], "text/javascript");
    assert.equal(res.headers["cache-control"], "no-cache");
    assert.equal(res.headers["access-control-allow-origin"], STOREFRONT_ORIGIN);
    assert.equal(res.body, readFileSync(new URL("../client.js", import.meta.url), "utf8"));
    assert.equal(recorded, undefined);
  });
});
