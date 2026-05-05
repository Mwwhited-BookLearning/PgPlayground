<#
.SYNOPSIS
    Builds the MyApp.Database pgpkg and deploys it to the local Docker Postgres.

.DESCRIPTION
    1. Starts the Docker stack (if not already running)
    2. Builds the sample MyApp.Database project â€” this runs `dotnet ef dbcontext script`
       then packages everything into MyApp.Database-1.0.0.pgpkg
    3. Deploys the package using `pgpkg deploy`

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
$connStr   = 'Host=localhost;Port=5432;Database=myapp;Username=myapp;Password=myapp'

# â”€â”€ 1. Start Docker stack â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
if (-not $SkipDockerUp) {
    Write-Host "Starting Docker stack..."
    Push-Location $PSScriptRoot
    docker compose up -d --wait
    Pop-Location
}

# â”€â”€ 2. Build the database package â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Host ""
Write-Host "Building MyApp.Database..."
dotnet build $dbProject
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed" }

# â”€â”€ 3. Deploy â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Write-Host ""
Write-Host "Deploying $pkgPath..."
$pgpkgArgs = @('deploy', $pkgPath, '--connection', $connStr)
if ($DryRun) { $pgpkgArgs += '--dry-run' }

pgpkg @pgpkgArgs
if ($LASTEXITCODE -ne 0) { throw "pgpkg deploy failed" }

Write-Host ""
Write-Host "Done. pgAdmin is available at http://localhost:5050"
Write-Host "  Email   : admin@pgproj.local"
Write-Host "  Password: pgadmin"
