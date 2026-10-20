# Storefront BFF

A small server that sits between a storefront and the API. It holds the store's
API key, the shopper's session token and a guest's cart token, so the browser
never sees any of them.

Every request to `/<path>` goes to `/<version>/storefront/<path>` on the API.
A new storefront endpoint works here with no change.

## Browser library

The BFF serves a browser library at `/client.js`. Storefront pages import it
from the BFF. They do not install it.

```js
const shop = await import("https://api.<shop>.gr/client.js");
```

The library sends each request to the BFF it came from, so it needs no config.
It is one ES module with no dependencies and no build step: `client.js`.

- Each function calls one endpoint and resolves to the API's response body.
- A failed request throws an `ApiError`. Use `error.code` to decide what to
  show. `error.retryAfter` gives the seconds from `Retry-After`, or `null`.
- If the BFF does not answer, the code is `bad_gateway`.
- `currentSession()` resolves to `null` when the shopper is signed out. When
  the page URL has `#handoff=<token>`, it first removes it from the URL and
  exchanges it for a session.
- `onSignedOut(listener)` calls the listener when a request finds the session
  gone. It returns a function that removes the listener.

| Function | Endpoint |
| --- | --- |
| `signIn({ email, password })` | `POST /session` |
| `signOut()` | `DELETE /session` |
| `currentSession()` | `POST /handoff` when the URL has one, then `GET /session` |
| `requestSignupCode(email)` | `POST /signup` |
| `completeSignup({ email, code, password })` | `PUT /signup` |
| `requestPasswordResetCode(email)` | `POST /password_reset` |
| `completePasswordReset({ email, code, password })` | `PUT /password_reset` |
| `listProducts({ limit, after })` | `GET /products` |
| `getProduct(slug)` | `GET /products/<slug>` |
| `listCategories()` | `GET /categories` |
| `listCategoryProducts(slug, { limit, after, filter })` | `GET /categories/<slug>/products` |
| `search(query, { limit, after, filter })` | `GET /search/<query>` |

Helpers that make no request:

| Function | Use |
| --- | --- |
| `filterPath(filter)` | Turns a filter into one URL path segment. The same filter always gives the same segment. |
| `parseFilterPath(segment)` | Reads a filter back from a segment. Give it the segment as it is in the URL. |
| `categoryLeaves(categories)` | Returns the categories with no children from `facets.categories`. |

## Config

| Variable | Required | Use |
| --- | --- | --- |
| `TOULOUSE_URL` | yes | API base URL |
| `TOULOUSE_API_VERSION` | yes | API version, such as `v1` |
| `TOULOUSE_API_KEY` | yes | The store's API key |
| `STOREFRONT_ORIGIN` | yes | The storefront's origin. CORS and the CSRF check allow only this one. |
| `PORT` | no | Listen port. Default 4000. |
| `TRUST_PROXY` | no | Set to `true` behind a proxy that appends to `X-Forwarded-For`. |

## Development

1. Seed the database. The seed issues a "Demo storefront" key for `demo-store`.
2. Copy that key's token from platform admin.
3. Create `storefront/bff/.env`:

   ```
   TOULOUSE_API_KEY=<the token>
   STOREFRONT_ORIGIN=<the storefront's origin>
   ```

4. Start it with `docker compose up bff`. It listens on port 4000.

## Tests

Node 24 or later. The server has no runtime dependencies. TypeScript and the
Node types are dev dependencies, for the type check only.

```bash
cd storefront/bff && npm install
```

```bash
cd storefront/bff && npm test && npm run typecheck
```
