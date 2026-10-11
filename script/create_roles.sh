#!/bin/sh
# Roles are cluster-wide, so no migration can create these. Runs as a Postgres
# init script on a fresh volume, and by hand against an existing one.
set -eu

export PGUSER="${PGUSER:-$POSTGRES_USER}"

create_role() {
  psql -v ON_ERROR_STOP=1 -v user="$1" -v password="$2" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'user', :'password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'user')
\gexec
SQL
}

# Already exists where it is the superuser, as in development.
create_role "$POSTGRES_USER" "$POSTGRES_PASSWORD"
create_role toulouse_app "$POSTGRES_APP_PASSWORD"
create_role toulouse_platform "$POSTGRES_PLATFORM_PASSWORD"
