# Tenant admin

The shared admin app where merchant staff manage their store. It is a static
browser app that talks only to the `/admin` API, with the staff session
cookie.

Vite, Vue 3 and Vue Router, in plain JS. The copy is Greek.

## Hosting

Each merchant reaches the app on `admin.<merchant domain>`. That host serves
the build and forwards `/admin/*` to the API, server to server. The browser
only ever talks to the admin host, so the staff cookie is first-party.

The host also serves `/store.json` with the store's slug:

```json
{ "slug": "<store slug>" }
```

Login then asks only for email and password. Without the file, login asks for
the slug too.

The proxy must send the client's address in `X-Forwarded-For`, and the API
must trust it. Otherwise every request looks like it comes from the proxy.

## Development

1. Start it with `docker compose up tenant-admin`. It starts the API too.
2. Open `http://localhost:5174` and log in with a staff member's email and
   password.

Vite serves `/store.json` from `STORE_SLUG`, which defaults to the seeded
store. To log in to another store by slug, start it with `STORE_SLUG=` set
empty.

Vite forwards `/admin` to the API, as the production proxy does. Development
invite and password reset emails link to this port, so it must not change.

## Tests

`npm test` runs the tests for the plain JS modules.

## Build

```bash
cd tenant-admin && npm ci && npm run build
```

Serve `dist/` with a fallback to `index.html` for every path that is not a
file and not under `/admin`.
