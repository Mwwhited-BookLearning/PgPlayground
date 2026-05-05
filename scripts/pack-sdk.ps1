<#
.SYNOPSIS
    Bumps the SDK version, repacks it to local-feed/, clears the NuGet cache,
    and updates all consuming .pgpkgproj files.

.PARAMETER Version
    New semantic version, e.g. 1.1.0

.EXAMPLE
    .\scripts\pack-sdk.ps1 -Version 1.1.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..')
$sdkCsproj  = Join-Path $repoRoot 'src\Cadwell.PgPkg.Sdk\Cadwell.PgPkg.Sdk.csproj'
$localFeed  = Join-Path $repoRoot 'local-feed'
$nugetCache = Join-Path $env:USERPROFILE '.nuget\packages\cadwell.pgpkg.sdk'

# ── 1. Bump version in SDK .csproj ───────────────────────────────────────────
Write-Host "Updating $sdkCsproj → $Version"
$content = Get-Content $sdkCsproj -Raw
$content = $content -replace '<Version>[^<]+</Version>', "<Version>$Version</Version>"
Set-Content $sdkCsproj $content -Encoding utf8

# ── 2. Rebuild & repack ───────────────────────────────────────────────────────
Write-Host "Packing SDK..."
dotnet pack $sdkCsproj -o $localFeed
if ($LASTEXITCODE -ne 0) { throw "dotnet pack failed" }

# ── 3. Clear the NuGet global packages cache for the SDK ─────────────────────
if (Test-Path $nugetCache) {
    Write-Host "Clearing NuGet cache: $nugetCache"
    Remove-Item $nugetCache -Recurse -Force
}

# ── 4. Update Sdk= attribute in all .pgpkgproj files ─────────────────────────
$projects = Get-ChildItem $repoRoot -Recurse -Filter '*.pgpkgproj' |
            Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' }

foreach ($proj in $projects) {
    $xml = Get-Content $proj.FullName -Raw
    if ($xml -match 'Sdk="Cadwell\.PgPkg\.Sdk/([^"]+)"') {
        $oldVer = $Matches[1]
        $xml = $xml -replace "Sdk=`"Cadwell\.PgPkg\.Sdk/$([regex]::Escape($oldVer))`"",
                              "Sdk=`"Cadwell.PgPkg.Sdk/$Version`""
        Set-Content $proj.FullName $xml -Encoding utf8
        Write-Host "Updated $($proj.Name): $oldVer → $Version"
    }
}

Write-Host ""
Write-Host "Done. SDK $Version is ready in local-feed/."
Write-Host "Run 'dotnet build samples\MyApp.Database\...' to verify."
