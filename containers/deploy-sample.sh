#!/usr/bin/env bash
# Builds the MyApp.Database pgpkg and deploys it to the local Docker Postgres.
#
# Usage:
#   ./deploy-sample.sh [--skip-docker-up] [--dry-run]

set -euo pipefail

SKIP_DOCKER=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docker-up) SKIP_DOCKER=true; shift ;;
    --dry-run)        DRY_RUN=true;     shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DB_PROJECT="$REPO_ROOT/samples/MyApp.Database/MyApp.Database.pgpkgproj"
PKG_PATH="$REPO_ROOT/samples/MyApp.Database/bin/Debug/net10.0/MyApp.Database-1.0.0.pgpkg"

# ── 1. Load .env ──────────────────────────────────────────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

if [[ ! -f "$ENV_FILE" && -f "$ENV_EXAMPLE" ]]; then
  echo ".env not found — copying from .env.example"
  cp "$ENV_EXAMPLE" "$ENV_FILE"
fi

# Defaults
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin
POSTGRES_DB=postgres
POSTGRES_PORT=5432
PGADMIN_EMAIL=admin@pgproj.local
PGADMIN_PASSWORD=admin
PGADMIN_PORT=5050
APP_DB=myapp
APP_DB_USER=myapp
APP_DB_PASSWORD=myapp

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

# ── 2. Regenerate pgadmin/pgpass and servers.json ─────────────────────────────
echo "Writing pgadmin/pgpass..."
printf 'postgres:%s:*:%s:%s' "$POSTGRES_PORT" "$POSTGRES_USER" "$POSTGRES_PASSWORD" \
  > "$SCRIPT_DIR/pgadmin/pgpass"

echo "Writing pgadmin/servers.json..."
cat > "$SCRIPT_DIR/pgadmin/servers.json" <<JSON
{
  "Servers": {
    "1": {
      "Name": "PgProj Local",
      "Group": "Servers",
      "Host": "postgres",
      "Port": $POSTGRES_PORT,
      "MaintenanceDB": "$POSTGRES_DB",
      "Username": "$POSTGRES_USER",
      "SSLMode": "prefer",
      "PassFile": "/pgpass"
    }
  }
}
JSON

# ── 3. Start Docker stack ─────────────────────────────────────────────────────
if [[ "$SKIP_DOCKER" == false ]]; then
  echo ""
  echo "Starting Docker stack..."
  docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d --wait
fi

# ── 4. Build ──────────────────────────────────────────────────────────────────
echo ""
echo "Building MyApp.Database..."
dotnet build "$DB_PROJECT"

# ── 5. Deploy ─────────────────────────────────────────────────────────────────
CONN_STR="Host=localhost;Port=${POSTGRES_PORT};Database=${APP_DB};Username=${APP_DB_USER};Password=${APP_DB_PASSWORD}"
echo ""
echo "Deploying $PKG_PATH..."
PGPKG_ARGS=(deploy "$PKG_PATH" --connection "$CONN_STR")
[[ "$DRY_RUN" == true ]] && PGPKG_ARGS+=(--dry-run)

pgpkg "${PGPKG_ARGS[@]}"

echo ""
echo "Done."
echo "  pgAdmin : http://localhost:$PGADMIN_PORT  ($PGADMIN_EMAIL / $PGADMIN_PASSWORD)"
echo "  Postgres: localhost:$POSTGRES_PORT  ($POSTGRES_USER / [see .env])"
