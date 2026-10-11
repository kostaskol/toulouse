# Toulouse

Rails 8.1 API-only application, running on Puma behind Thruster.

## Running it

```sh
docker compose up --build
```

That builds the `development` target of the `Dockerfile` and starts three
services — `api`, `postgres`, `redis` — on a single bridge network named
`toulouse`. The app is at http://localhost:3000, with a health endpoint at
`/up`. The database is created and migrated on boot by `bin/docker-entrypoint`.

Postgres (5432) and Redis (6379) are also published to localhost, so you can
connect to them from `psql`, `redis-cli`, or a Rails server running natively.

| Command | |
|---|---|
| `docker compose exec api ./bin/rails console` | Rails console |
| `docker compose exec api ./bin/rspec` | Test suite |
| `docker compose exec api ./bin/rails generate ...` | Generators |
| `docker compose build api` | Rebuild after changing the Gemfile |
| `docker compose down -v` | Stop and delete the data volumes |

Source is bind-mounted, so code changes are picked up without a rebuild. Gems
are baked into the image, so adding one needs `docker compose build api`.

## Configuration

`config/database.yml` reads `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`
and `POSTGRES_PASSWORD`, defaulting to `localhost` when unset. Compose points
them at the `postgres` service. Redis is at `REDIS_URL`.

The app connects as `toulouse_app`, a role that row-level security applies
to. Platform admin connects as `toulouse_platform`, which row-level security
also applies to and which alone can reach the `platform` schema. Their
passwords are in `POSTGRES_APP_PASSWORD` and `POSTGRES_PLATFORM_PASSWORD`.
`POSTGRES_USER` owns the tables and runs every database task. Compose creates
both roles when the Postgres volume is first initialised. On a volume that
predates either, create them once:

```sh
docker compose exec -u postgres postgres sh /docker-entrypoint-initdb.d/create_roles.sh
```

The schema lives in `db/structure.sql`, because policies and grants have no
`schema.rb` form.

Rails.cache, Active Job and Action Cable use the Solid adapters, which are
backed by Postgres rather than Redis. The `redis` gem is available for anything
you want to put on Redis directly.

## Platform admin

Sign in at `/platform` with email, password and an authenticator code. There
is no signup. Create an admin, or reset one who lost their password or phone:

```sh
docker compose exec api bin/rails platform:admins:create
```

It prints a secret and an `otpauth://` URI for the authenticator app. In
production, run it through `kamal app exec --interactive`.

The development seed creates `admin@example.com` with the seed password and a
new secret on every run. Print its current code with:

```sh
docker compose exec api bin/rails platform:admins:code EMAIL=admin@example.com
```

## Production image

```sh
docker build -t toulouse .
```

The default target runs as a non-root user and starts Thruster in front of
Puma on port 80. Thruster handles HTTP/2, TLS, compression and X-Sendfile, so
a separate nginx layer is generally not needed. `config/deploy.yml` holds the
generated Kamal configuration if you want to deploy that way.

## Production database

Production uses the same three roles as development:

| Role | Password variable | Use |
|---|---|---|
| `toulouse` | `POSTGRES_PASSWORD` | Owns the tables. Runs `db:prepare` when the server starts. |
| `toulouse_app` | `POSTGRES_APP_PASSWORD` | The API. Row-level security applies. Owns the Solid databases. |
| `toulouse_platform` | `POSTGRES_PLATFORM_PASSWORD` | Platform admin. Row-level security applies. |

`config/deploy.yml` sets the owner name in `POSTGRES_USER`. `.kamal/secrets`
reads the three passwords from your environment.

The app cannot create roles or databases. Before the first deploy, do these
steps as a Postgres superuser:

1. Create the roles. Set `PGHOST` and `PGUSER` to the server and the superuser.
   Set `POSTGRES_USER` and the password variables from the table above. Then run:

   ```sh
   script/create_roles.sh
   ```

2. Create the databases:

   ```sql
   CREATE DATABASE toulouse_production OWNER toulouse;
   CREATE DATABASE toulouse_production_cache OWNER toulouse_app;
   CREATE DATABASE toulouse_production_queue OWNER toulouse_app;
   CREATE DATABASE toulouse_production_cable OWNER toulouse_app;
   ```

After a deploy, make sure that the API cannot see past row-level security:

```sh
bin/kamal app exec "bin/rails tenancy:verify"
```

The task fails if a role can bypass row-level security, owns a table or sees
tenant rows with no tenant set, or if the app role can reach the `platform`
schema.
