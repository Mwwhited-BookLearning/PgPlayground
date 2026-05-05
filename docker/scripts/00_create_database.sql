-- Creates the myapp database and a dedicated app user.
-- Runs automatically on first container start via docker-entrypoint-initdb.d.

SELECT 'CREATE DATABASE myapp'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'myapp') \gexec

\connect myapp

CREATE SCHEMA IF NOT EXISTS public;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'myapp') THEN
    CREATE ROLE myapp WITH LOGIN PASSWORD 'myapp';
  END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp;
GRANT ALL ON SCHEMA public TO myapp;
