# Tenant admin

The shared admin app where merchant staff manage their store. It is a static
browser app that talks only to the `/admin` API, with the staff session
cookie.

Vite, Vue 3 and Vue Router, in plain JS. The copy is Greek.

## Development

1. Start it with `docker compose up tenant-admin`. It starts the API too.
2. Open `http://localhost:5174` and log in with a store slug and a staff
   member's email and password.

The API admits one admin origin. In development it is `http://localhost:5174`,
so the port must not change. Invite and password reset emails link here too.

`VITE_API_URL` in `.env.development` tells the app where the API is.

## Tests

`npm test` runs the tests for the API client and the price parser.

## Build

Set `VITE_API_URL` to the API's public URL. The build stops when it is not
set. Set the API's `ADMIN_ORIGIN` to the origin that serves the build.

```bash
cd tenant-admin && npm ci && VITE_API_URL=<the API URL> npm run build
```
