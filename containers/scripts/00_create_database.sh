#!/usr/bin/env bash
# Runs automatically on first container start via docker-entrypoint-initdb.d.
# Creates the application database and dedicated role using values from docker-compose env.
set -e

APP_DB="${APP_DB:-myapp}"
APP_DB_USER="${APP_DB_USER:-myapp}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-myapp}"

echo "==> Creating database: $APP_DB"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
	SELECT 'CREATE DATABASE "$APP_DB"'
	WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$APP_DB')
	\gexec
EOSQL

echo "==> Configuring database: $APP_DB"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$APP_DB" <<-EOSQL
	CREATE SCHEMA IF NOT EXISTS public;

	DO \$do\$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$APP_DB_USER') THEN
	    CREATE ROLE "$APP_DB_USER" WITH LOGIN PASSWORD '$APP_DB_PASSWORD';
	  END IF;
	END
	\$do\$;

	GRANT ALL PRIVILEGES ON DATABASE "$APP_DB" TO "$APP_DB_USER";
	GRANT ALL ON SCHEMA public TO "$APP_DB_USER";
EOSQL

echo "==> Done: $APP_DB_USER@$APP_DB ready"
