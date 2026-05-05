#!/usr/bin/env bash
# pack-sdk.sh — Bump the SDK version, repack to local-feed/, clear NuGet cache,
# and update all consuming .pgpkgproj files.
#
# Usage: ./scripts/pack-sdk.sh <version>
# Example: ./scripts/pack-sdk.sh 1.1.0

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_CSPROJ="$REPO_ROOT/src/Cadwell.PgPkg.Sdk/Cadwell.PgPkg.Sdk.csproj"
LOCAL_FEED="$REPO_ROOT/local-feed"
NUGET_CACHE="${HOME}/.nuget/packages/cadwell.pgpkg.sdk"

# 1. Bump version in SDK .csproj
echo "Updating $SDK_CSPROJ → $VERSION"
sed -i "s|<Version>[^<]*</Version>|<Version>$VERSION</Version>|" "$SDK_CSPROJ"

# 2. Rebuild & repack
echo "Packing SDK..."
dotnet pack "$SDK_CSPROJ" -o "$LOCAL_FEED"

# 3. Clear NuGet global packages cache for the SDK
if [[ -d "$NUGET_CACHE" ]]; then
  echo "Clearing NuGet cache: $NUGET_CACHE"
  rm -rf "$NUGET_CACHE"
fi

# 4. Update Sdk= attribute in all .pgpkgproj files
while IFS= read -r -d '' proj; do
  old=$(grep -oP 'Sdk="Cadwell\.PgPkg\.Sdk/\K[^"]+' "$proj" || true)
  if [[ -n "$old" ]]; then
    sed -i "s|Sdk=\"Cadwell\.PgPkg\.Sdk/$old\"|Sdk=\"Cadwell.PgPkg.Sdk/$VERSION\"|g" "$proj"
    echo "Updated $(basename "$proj"): $old → $VERSION"
  fi
done < <(find "$REPO_ROOT" \
           -not \( -path "*/bin/*" -o -path "*/obj/*" \) \
           -name "*.pgpkgproj" -print0)

echo ""
echo "Done. SDK $VERSION is ready in local-feed/."
