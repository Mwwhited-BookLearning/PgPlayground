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
CONN_STR="Host=localhost;Port=5432;Database=myapp;Username=myapp;Password=myapp"

# 1. Start Docker stack
if [[ "$SKIP_DOCKER" == false ]]; then
  echo "Starting Docker stack..."
  docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d --wait
fi

# 2. Build
echo ""
echo "Building MyApp.Database..."
dotnet build "$DB_PROJECT"

# 3. Deploy
echo ""
echo "Deploying $PKG_PATH..."
PGPKG_ARGS=(deploy "$PKG_PATH" --connection "$CONN_STR")
[[ "$DRY_RUN" == true ]] && PGPKG_ARGS+=(--dry-run)

pgpkg "${PGPKG_ARGS[@]}"

echo ""
echo "Done. pgAdmin is available at http://localhost:5050"
echo "  Email   : admin@pgproj.local"
echo "  Password: pgadmin"
