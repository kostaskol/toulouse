#!/bin/sh
# Roles are cluster-wide, so no migration can create this one. Runs as a
# Postgres init script on a fresh volume, and by hand against an existing one.
set -eu

export PGUSER="${PGUSER:-$POSTGRES_USER}"

psql -v ON_ERROR_STOP=1 \
  -v app_user="$POSTGRES_APP_USER" \
  -v app_password="$POSTGRES_APP_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'app_user')
\gexec
SQL
