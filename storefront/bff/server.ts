import http from "node:http";

export type Config = {
  toulouseUrl: string;
  apiVersion: string;
  apiKey: string;
  storefrontOrigin: string;
  trustProxy: boolean;
};

type Upstream = { status: number; headers: Headers; body: Buffer };
type SessionRoute = "issue" | "clear";

export const SESSION_COOKIE = "__Host-session";

// Keyed by route, not by a token field, so a future endpoint returning some other token passes through untouched.
const SESSION_ROUTES: Record<string, SessionRoute> = {
  "POST /session": "issue",
  "PUT /signup": "issue",
  "PUT /password_reset": "issue",
  "DELETE /session": "clear"
};

const COOKIE_ATTRIBUTES = "Path=/; Secure; HttpOnly; SameSite=Lax";
const CLEARED_SESSION_COOKIE = `${SESSION_COOKIE}=; ${COOKIE_ATTRIBUTES}; Expires=${new Date(0).toUTCString()}`;
const UPSTREAM_TIMEOUT_MS = 10_000;
const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);
const FORWARDED_REQUEST_HEADERS = ["content-type", "accept"];
// fetch has already decompressed the body, so its encoding and length no longer apply.
const DROPPED_RESPONSE_HEADERS = new Set([
  "content-encoding", "content-length", "transfer-encoding", "connection", "set-cookie", "location"
]);

/**
 * Forwards storefront requests to the API with the tenant key and the shopper's session.
 *
 * @param config [Config]
 * @return [http.Server]
 */
export function createBff(config: Config): http.Server {
  return http.createServer((req, res) => {
    handle(config, req, res).catch((error) => {
      console.error(error);
      sendError(res, 500, "internal_error", "The storefront server failed.");
    });
  });
}

async function handle(config: Config, req: http.IncomingMessage, res: http.ServerResponse) {
  const method = req.method ?? "GET";
  const origin = req.headers.origin;

  res.setHeader("vary", "Origin");
  if (origin === config.storefrontOrigin) {
    res.setHeader("access-control-allow-origin", origin);
    res.setHeader("access-control-allow-credentials", "true");
    res.setHeader("access-control-expose-headers", "Retry-After");
  }

  if (method === "OPTIONS") {
    res.setHeader("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE");
    res.setHeader("access-control-allow-headers", "Content-Type, Accept");
    res.writeHead(204).end();
    return;
  }

  // SameSite=Lax still sends the cookie from sibling subdomains, so the origin itself has to match.
  if (!SAFE_METHODS.has(method) && origin !== config.storefrontOrigin) {
    sendError(res, 403, "forbidden_origin", "The request does not come from this storefront.");
    return;
  }

  // Parsing resolves dot segments, including encoded ones, before the prefix is added.
  const url = new URL(req.url ?? "/", "http://bff");
  // Rails ignores a trailing slash, so it would otherwise reach a session route the table misses.
  const pathname = url.pathname.replace(/\/+$/, "") || "/";

  let upstream: Upstream;
  try {
    upstream = await forward(config, req, method, `${pathname}${url.search}`);
  } catch (error) {
    console.error("Upstream request failed:", error instanceof Error ? (error.cause ?? error) : error);
    sendError(res, 502, "bad_gateway", "The API did not answer.");
    return;
  }

  respond(res, upstream, SESSION_ROUTES[`${method} ${pathname}`]);
}

async function forward(config: Config, req: http.IncomingMessage, method: string, path: string): Promise<Upstream> {
  const response = await fetch(`${config.toulouseUrl}/${config.apiVersion}/storefront${path}`, {
    method,
    headers: upstreamHeaders(config, req),
    body: method === "GET" || method === "HEAD" ? null : req,
    duplex: "half",
    redirect: "manual",
    signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS)
  });

  return { status: response.status, headers: response.headers, body: Buffer.from(await response.arrayBuffer()) };
}

function respond(res: http.ServerResponse, upstream: Upstream, sessionRoute: SessionRoute | undefined) {
  const succeeded = upstream.status >= 200 && upstream.status < 300;
  let body = upstream.body;
  let cookie: string | undefined;

  if (sessionRoute === "issue" && succeeded) {
    const { token, ...session }: { token?: unknown; expires_at?: unknown } = JSON.parse(body.toString());
    cookie = sessionCookie(token, session.expires_at);
    body = Buffer.from(JSON.stringify(session));
  } else if ((sessionRoute === "clear" && succeeded) || isInvalidSession(upstream)) {
    cookie = CLEARED_SESSION_COOKIE;
  }

  // Appended, so the API's Vary joins Vary: Origin rather than replacing it.
  for (const [name, value] of upstream.headers) {
    if (!DROPPED_RESPONSE_HEADERS.has(name)) res.appendHeader(name, value);
  }
  if (cookie) res.setHeader("set-cookie", cookie);

  res.writeHead(upstream.status).end(body);
}

function upstreamHeaders(config: Config, req: http.IncomingMessage) {
  const headers: Record<string, string> = {
    "x-api-key": config.apiKey,
    "x-shopper-ip": shopperIp(config, req)
  };

  for (const name of FORWARDED_REQUEST_HEADERS) {
    const value = req.headers[name];
    if (typeof value === "string") headers[name] = value;
  }

  const token = readCookie(req.headers.cookie, SESSION_COOKIE);
  if (token) headers.authorization = `Bearer ${token}`;

  return headers;
}

function shopperIp(config: Config, req: http.IncomingMessage) {
  const forwarded = req.headers["x-forwarded-for"];

  // The proxy appends the address it saw, so only the last entry is out of the client's hands.
  if (config.trustProxy && typeof forwarded === "string") return forwarded.split(",").at(-1)?.trim() ?? "";

  return req.socket.remoteAddress ?? "";
}

function readCookie(header: string | undefined, name: string) {
  for (const pair of header?.split(";") ?? []) {
    const [key, ...value] = pair.trim().split("=");
    if (key === name) return value.join("=");
  }
}

function sessionCookie(token: unknown, expiresAt: unknown) {
  const expires = new Date(String(expiresAt));
  if (typeof token !== "string" || isNaN(expires.getTime())) {
    throw new Error("The API issued a session without a token or a valid expires_at.");
  }

  return `${SESSION_COOKIE}=${token}; ${COOKIE_ATTRIBUTES}; Expires=${expires.toUTCString()}`;
}

function isInvalidSession({ status, headers, body }: Upstream) {
  if (status !== 401 || !headers.get("content-type")?.includes("application/json")) return false;

  const { errors }: { errors: { code: string }[] } = JSON.parse(body.toString());
  return errors.some((error) => error.code === "invalid_session");
}

function sendError(res: http.ServerResponse, status: number, code: string, message: string) {
  res.writeHead(status, { "content-type": "application/json" }).end(JSON.stringify({ errors: [{ code, message }] }));
}
