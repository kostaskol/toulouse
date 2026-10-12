# Demo storefront

A shop called "Λινό" for the `demo-store` tenant. It shows each page in the
storefront checklist and uses the browser library that the BFF serves.

Vite, Vue 3 and Vue Router, in plain JS.

## Development

1. Seed the database. The seed adds the demo catalog.
2. Set up the BFF. See `storefront/bff/README.md`. Set its
   `STOREFRONT_ORIGIN` to `http://localhost:5173`.
3. Start the demo with `docker compose up storefront`. It starts the BFF too.
4. Open `http://localhost:5173` in Chrome or Firefox.

Safari can refuse the `Secure` session cookie on `http://localhost`. If it
does, log in does not stay.

`VITE_BFF_URL` in `.env.development` tells the demo where to load the library
from.

## Build

Set `VITE_BFF_URL` to the BFF's public URL. The build stops when it is not set.

```bash
cd storefront/demo && npm ci && VITE_BFF_URL=<the BFF URL> npm run build
```
