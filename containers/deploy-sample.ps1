<#
.SYNOPSIS
    Builds the MyApp.Database pgpkg and deploys it to the local Docker Postgres.

.DESCRIPTION
    1. Loads .env (copies .env.example if .env does not exist)
    2. Regenerates pgadmin/pgpass and pgadmin/servers.json from current .env values
    3. Starts the Docker stack (if not already running)
    4. Builds the sample MyApp.Database project
    5. Deploys the package using `pgpkg deploy`

.PARAMETER SkipDockerUp
    Skip `docker compose up`; assume the stack is already running.

.PARAMETER DryRun
    Pass --dry-run to pgpkg deploy (show diff without applying).
#>
[CmdletBinding()]
param(
    [switch] $SkipDockerUp,
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot  = Resolve-Path (Join-Path $PSScriptRoot '..')
$dbProject = Join-Path $repoRoot 'samples\MyApp.Database\MyApp.Database.pgpkgproj'
$pkgPath   = Join-Path $repoRoot 'samples\MyApp.Database\bin\Debug\net10.0\MyApp.Database-1.0.0.pgpkg'

# ── 1. Load .env ──────────────────────────────────────────────────────────────
$envFile     = Join-Path $PSScriptRoot '.env'
$envExample  = Join-Path $PSScriptRoot '.env.example'

if (-not (Test-Path $envFile)) {
    if (Test-Path $envExample) {
        Write-Host ".env not found — copying from .env.example"
        Copy-Item $envExample $envFile
    }
}

# Defaults (overridden by .env below)
$POSTGRES_USER     = 'admin'
$POSTGRES_PASSWORD = 'admin'
$POSTGRES_DB       = 'postgres'
$POSTGRES_PORT     = '5432'
$PGADMIN_EMAIL     = 'admin@pgproj.local'
$PGADMIN_PASSWORD  = 'admin'
$PGADMIN_PORT      = '5050'
$APP_DB            = 'myapp'
$APP_DB_USER       = 'myapp'
$APP_DB_PASSWORD   = 'myapp'

if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            Set-Variable -Name $Matches[1] -Value $Matches[2].Trim() -Scope Script
        }
    }
}

# ── 2. Regenerate pgadmin/pgpass and servers.json ─────────────────────────────
$pgpassPath     = Join-Path $PSScriptRoot 'pgadmin\pgpass'
$serversJsonPath = Join-Path $PSScriptRoot 'pgadmin\servers.json'

Write-Host "Writing pgadmin/pgpass..."
Set-Content $pgpassPath -Value "postgres:${POSTGRES_PORT}:*:${POSTGRES_USER}:${POSTGRES_PASSWORD}" -Encoding utf8 -NoNewline

Write-Host "Writing pgadmin/servers.json..."
@"
{
  "Servers": {
    "1": {
      "Name": "PgProj Local",
      "Group": "Servers",
      "Host": "postgres",
      "Port": $([int]$POSTGRES_PORT),
      "MaintenanceDB": "$POSTGRES_DB",
      "Username": "$POSTGRES_USER",
      "SSLMode": "prefer",
      "PassFile": "/pgpass"
    }
  }
}
"@ | Set-Content $serversJsonPath -Encoding utf8

# ── 3. Start Docker stack ─────────────────────────────────────────────────────
if (-not $SkipDockerUp) {
    Write-Host ""
    Write-Host "Starting Docker stack..."
    Push-Location $PSScriptRoot
    docker compose up -d --wait
    Pop-Location
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }
}

# ── 4. Build the database package ─────────────────────────────────────────────
Write-Host ""
Write-Host "Building MyApp.Database..."
dotnet build $dbProject
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed" }

# ── 5. Deploy ─────────────────────────────────────────────────────────────────
$connStr   = "Host=localhost;Port=${POSTGRES_PORT};Database=${APP_DB};Username=${APP_DB_USER};Password=${APP_DB_PASSWORD}"
Write-Host ""
Write-Host "Deploying $pkgPath..."
$pgpkgArgs = @('deploy', $pkgPath, '--connection', $connStr)
if ($DryRun) { $pgpkgArgs += '--dry-run' }

pgpkg @pgpkgArgs
if ($LASTEXITCODE -ne 0) { throw "pgpkg deploy failed" }

Write-Host ""
Write-Host "Done."
Write-Host "  pgAdmin : http://localhost:$PGADMIN_PORT  ($PGADMIN_EMAIL / $PGADMIN_PASSWORD)"
Write-Host "  Postgres: localhost:$POSTGRES_PORT  ($POSTGRES_USER / [see .env])"
