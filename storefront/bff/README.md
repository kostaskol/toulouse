# Storefront BFF

A small server that sits between a storefront and the API. It holds the store's
API key and the shopper's session token, so the browser never sees either.

Every request to `/<path>` goes to `/<version>/storefront/<path>` on the API.
A new storefront endpoint works here with no change.

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
