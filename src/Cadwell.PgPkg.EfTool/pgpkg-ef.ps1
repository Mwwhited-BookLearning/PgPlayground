<#
.SYNOPSIS
    Extracts a PostgreSQL schema from an Entity Framework Core project and
    stages it so the Cadwell.PgPkg.Sdk build can pick it up.

.DESCRIPTION
    Runs `dotnet ef dbcontext script` (idempotent migration script) against the
    target EF project and writes the resulting SQL into the expected pgpkg
    schema layout:

        <OutputDir>\schema\<DatabaseName>\<MigrationName>.sql

    The output directory can then be referenced by a .pgpkg project file.

.PARAMETER Project
    Path to the EF Core .csproj (or directory containing it).

.PARAMETER StartupProject
    Optional: path to the startup project (passed to `dotnet ef`).

.PARAMETER Context
    Optional: DbContext name (passed to `dotnet ef`).

.PARAMETER DatabaseName
    Name of the logical database.  Used as the sub-folder inside schema\.
    Defaults to the project directory name.

.PARAMETER OutputDir
    Directory to write the staged schema into.
    Defaults to .\pgpkg-schema next to the EF project.

.PARAMETER Idempotent
    Generate an idempotent migration script (default: true).

.EXAMPLE
    .\pgpkg-ef.ps1 -Project .\src\MyApp.Data -DatabaseName myapp

.EXAMPLE
    .\pgpkg-ef.ps1 -Project .\src\MyApp.Data -Context AppDbContext -DatabaseName myapp -OutputDir .\deploy\schema
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Project,
    [string]               $StartupProject,
    [string]               $Context,
    [string]               $DatabaseName,
    [string]               $OutputDir,
    [bool]                 $Idempotent = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve project path
$projectPath = Resolve-Path $Project
if (Test-Path $projectPath -PathType Container) {
    $csproj = Get-ChildItem $projectPath -Filter '*.csproj' | Select-Object -First 1
    if (-not $csproj) { throw "No .csproj found in $projectPath" }
    $projectPath = $csproj.FullName
}

$projectDir = Split-Path $projectPath -Parent

# Defaults
if (-not $DatabaseName) { $DatabaseName = Split-Path $projectDir -Leaf }
if (-not $OutputDir)    { $OutputDir = Join-Path $projectDir 'pgpkg-schema' }

$schemaDir = Join-Path $OutputDir "schema\$DatabaseName"
New-Item -ItemType Directory -Path $schemaDir -Force | Out-Null

# Build dotnet ef arguments
$efArgs = @(
    'ef', 'dbcontext', 'script',
    '--project', $projectPath,
    '--output',  (Join-Path $schemaDir '001_migrations.sql'),
    '--no-build'
)

if ($StartupProject) { $efArgs += '--startup-project', $StartupProject }
if ($Context)        { $efArgs += '--context', $Context }
if ($Idempotent)     { $efArgs += '--idempotent' }

Write-Host "Running: dotnet $($efArgs -join ' ')"
& dotnet @efArgs

if ($LASTEXITCODE -ne 0) {
    throw "dotnet ef exited with code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Schema staged to: $schemaDir"
Write-Host "Add the following to your .pgpkg project to include this output:"
Write-Host ""
Write-Host "  <ItemGroup>"
Write-Host "    <PgSchema Include=`"$schemaDir\**\*.sql`" />"
Write-Host "  </ItemGroup>"
