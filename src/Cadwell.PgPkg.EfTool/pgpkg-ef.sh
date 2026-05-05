#!/usr/bin/env bash
# pgpkg-ef.sh — Extract a PostgreSQL schema from an EF Core project and stage
# it for Cadwell.PgPkg.Sdk.
#
# Usage:
#   ./pgpkg-ef.sh <project> [options]
#
# Options:
#   --startup-project <path>   Startup project passed to dotnet ef
#   --context <name>           DbContext name
#   --database-name <name>     Logical database name (default: project dir name)
#   --output-dir <path>        Where to write schema\ (default: ./pgpkg-schema)
#   --no-idempotent            Omit --idempotent flag from dotnet ef
#   -h, --help                 Show this help
#
# Example:
#   ./pgpkg-ef.sh ./src/MyApp.Data --database-name myapp

set -euo pipefail

PROJECT=""
STARTUP_PROJECT=""
CONTEXT=""
DATABASE_NAME=""
OUTPUT_DIR=""
IDEMPOTENT=true

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)            usage ;;
    --startup-project)    STARTUP_PROJECT="$2"; shift 2 ;;
    --context)            CONTEXT="$2"; shift 2 ;;
    --database-name)      DATABASE_NAME="$2"; shift 2 ;;
    --output-dir)         OUTPUT_DIR="$2"; shift 2 ;;
    --no-idempotent)      IDEMPOTENT=false; shift ;;
    -*)                   echo "Unknown option: $1" >&2; exit 1 ;;
    *)                    PROJECT="$1"; shift ;;
  esac
done

if [[ -z "$PROJECT" ]]; then
  echo "Error: <project> argument is required." >&2
  exit 1
fi

# Resolve .csproj
if [[ -d "$PROJECT" ]]; then
  PROJECT=$(find "$PROJECT" -maxdepth 1 -name '*.csproj' | head -1)
  [[ -z "$PROJECT" ]] && { echo "No .csproj found in directory." >&2; exit 1; }
fi
PROJECT_DIR=$(dirname "$(realpath "$PROJECT")")

[[ -z "$DATABASE_NAME" ]] && DATABASE_NAME=$(basename "$PROJECT_DIR")
[[ -z "$OUTPUT_DIR"    ]] && OUTPUT_DIR="$PROJECT_DIR/pgpkg-schema"

SCHEMA_DIR="$OUTPUT_DIR/schema/$DATABASE_NAME"
mkdir -p "$SCHEMA_DIR"

EF_ARGS=(ef dbcontext script --project "$PROJECT" --output "$SCHEMA_DIR/001_migrations.sql" --no-build)
[[ -n "$STARTUP_PROJECT" ]] && EF_ARGS+=(--startup-project "$STARTUP_PROJECT")
[[ -n "$CONTEXT"         ]] && EF_ARGS+=(--context "$CONTEXT")
[[ "$IDEMPOTENT" == true ]] && EF_ARGS+=(--idempotent)

echo "Running: dotnet ${EF_ARGS[*]}"
dotnet "${EF_ARGS[@]}"

echo ""
echo "Schema staged to: $SCHEMA_DIR"
echo "Add the following to your .pgpkg project to include this output:"
echo ""
echo "  <ItemGroup>"
echo "    <PgSchema Include=\"$SCHEMA_DIR/**/*.sql\" />"
echo "  </ItemGroup>"
