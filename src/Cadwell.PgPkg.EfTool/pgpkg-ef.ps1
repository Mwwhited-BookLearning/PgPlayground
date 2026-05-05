<#
.SYNOPSIS
    Extracts a PostgreSQL desired-state schema from an Entity Framework Core
    project and stages it for Cadwell.PgPkg.Sdk.

.DESCRIPTION
    Builds the target EF project, then runs the SchemaScript helper
    (MyApp.Data\SchemaScript or equivalent) which calls
    DbContext.GenerateCreateScript() to produce a pure desired-state SQL file.

    Output layout mirrors what pgschema expects:
        <OutputDir>\schema\<DatabaseName>\001_schema.sql

    No EF migrations are used or required.

.PARAMETER Project
    Path to the EF Core .csproj (or directory containing it).

.PARAMETER SchemaScriptProject
    Path to the SchemaScript .csproj that wraps GenerateCreateScript().
    Defaults to <Project>\SchemaScript\SchemaScript.csproj.

.PARAMETER DatabaseName
    Name of the logical database; used as the sub-folder inside schema\.
    Defaults to the EF project directory name.

.PARAMETER OutputDir
    Where to write schema\. Defaults to .\pgpkg-schema next to the EF project.

.EXAMPLE
    .\pgpkg-ef.ps1 -Project .\samples\MyApp.Data -DatabaseName myapp

.EXAMPLE
    .\pgpkg-ef.ps1 -Project .\samples\MyApp.Data `
                   -SchemaScriptProject .\samples\MyApp.Data\SchemaScript\SchemaScript.csproj `
                   -DatabaseName myapp -OutputDir .\MyApp.Database\pgpkg-schema
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Project,
    [string]               $SchemaScriptProject,
    [string]               $DatabaseName,
    [string]               $OutputDir
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
if (-not $SchemaScriptProject) {
    $SchemaScriptProject = Join-Path $projectDir 'SchemaScript\SchemaScript.csproj'
}
if (-not (Test-Path $SchemaScriptProject)) {
    throw "SchemaScript project not found at '$SchemaScriptProject'. " +
          "Create a console project that calls DbContext.GenerateCreateScript() and accepts an output path as args[0]."
}
if (-not $DatabaseName) { $DatabaseName = Split-Path $projectDir -Leaf }
if (-not $OutputDir)    { $OutputDir = Join-Path $projectDir 'pgpkg-schema' }

$schemaDir = Join-Path $OutputDir "schema\$DatabaseName"
New-Item -ItemType Directory -Path $schemaDir -Force | Out-Null
$outputFile = Join-Path $schemaDir '001_schema.sql'

# Build then run the schema script generator
Write-Host "Building $SchemaScriptProject..."
dotnet build $SchemaScriptProject
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed" }

Write-Host "Generating schema SQL..."
dotnet run --project $SchemaScriptProject --no-build -- $outputFile
if ($LASTEXITCODE -ne 0) { throw "SchemaScript failed" }

Write-Host ""
Write-Host "Schema staged to: $schemaDir"
Write-Host "Add the following to your .pgpkg project to include this output:"
Write-Host ""
Write-Host "  <ItemGroup>"
Write-Host "    <PgSchema Include=`"$schemaDir\**\*.sql`" />"
Write-Host "  </ItemGroup>"
