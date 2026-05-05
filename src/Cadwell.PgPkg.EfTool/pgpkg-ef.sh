#!/usr/bin/env bash
# pgpkg-ef.sh — Extract a PostgreSQL desired-state schema from an EF Core
# project and stage it for Cadwell.PgPkg.Sdk.
#
# Builds the SchemaScript helper project (which calls GenerateCreateScript())
# and runs it to produce a pure desired-state SQL file.
# No EF migrations are used or required.
#
# Usage:
#   ./pgpkg-ef.sh <project> [options]
#
# Options:
#   --schema-script <path>   Path to SchemaScript .csproj
#                            (default: <project>/SchemaScript/SchemaScript.csproj)
#   --database-name <name>   Logical database name (default: project dir name)
#   --output-dir <path>      Where to write schema/ (default: ./pgpkg-schema)
#   -h, --help               Show this help
#
# Example:
#   ./pgpkg-ef.sh ./samples/MyApp.Data --database-name myapp

set -euo pipefail

PROJECT=""
SCHEMA_SCRIPT=""
DATABASE_NAME=""
OUTPUT_DIR=""

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)           usage ;;
    --schema-script)     SCHEMA_SCRIPT="$2"; shift 2 ;;
    --database-name)     DATABASE_NAME="$2"; shift 2 ;;
    --output-dir)        OUTPUT_DIR="$2"; shift 2 ;;
    -*)                  echo "Unknown option: $1" >&2; exit 1 ;;
    *)                   PROJECT="$1"; shift ;;
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

[[ -z "$SCHEMA_SCRIPT"  ]] && SCHEMA_SCRIPT="$PROJECT_DIR/SchemaScript/SchemaScript.csproj"
[[ -z "$DATABASE_NAME"  ]] && DATABASE_NAME=$(basename "$PROJECT_DIR")
[[ -z "$OUTPUT_DIR"     ]] && OUTPUT_DIR="$PROJECT_DIR/pgpkg-schema"

if [[ ! -f "$SCHEMA_SCRIPT" ]]; then
  echo "Error: SchemaScript project not found at '$SCHEMA_SCRIPT'." >&2
  echo "Create a console project that calls DbContext.GenerateCreateScript() and accepts an output path as args[0]." >&2
  exit 1
fi

SCHEMA_DIR="$OUTPUT_DIR/schema/$DATABASE_NAME"
mkdir -p "$SCHEMA_DIR"
OUTPUT_FILE="$SCHEMA_DIR/001_schema.sql"

echo "Building $SCHEMA_SCRIPT..."
dotnet build "$SCHEMA_SCRIPT"

echo "Generating schema SQL..."
dotnet run --project "$SCHEMA_SCRIPT" --no-build -- "$OUTPUT_FILE"

echo ""
echo "Schema staged to: $SCHEMA_DIR"
echo "Add the following to your .pgpkg project to include this output:"
echo ""
echo "  <ItemGroup>"
echo "    <PgSchema Include=\"$SCHEMA_DIR/**/*.sql\" />"
echo "  </ItemGroup>"
