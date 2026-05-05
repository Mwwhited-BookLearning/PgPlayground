# Engineering Guide

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| .NET SDK | 10.0+ | `dotnet --version` |
| dotnet-ef | latest | `dotnet tool install --global dotnet-ef` (design-time only) |
| pgschema | latest | Install binary; add to PATH or set `PGSCHEMA_PATH` |
| Docker Desktop | latest | For the local Postgres + pgAdmin stack |
| PowerShell | 5.1+ or pwsh | For `pgpkg-ef.ps1` and `deploy-sample.ps1` |
| bash | any | For `pgpkg-ef.sh` and `deploy-sample.sh` on Linux/macOS |
| PostgreSQL | 14+ | Target server (provided by Docker stack) |

---

## Repository Layout

```
PgProj/
├── .gitignore
├── .gitattributes
├── nuget.config                   ← points at local-feed/ for SDK development
├── local-feed/                    ← packed NuGet packages (not committed — see .gitignore)
├── containers/
│   ├── docker-compose.yml         ← Postgres 17 + pgAdmin 4
│   ├── pgadmin/servers.json       ← pre-wired pgAdmin server connection
│   ├── scripts/00_create_database.sql
│   ├── deploy-sample.ps1          ← one-shot: up containers, build, deploy
│   └── deploy-sample.sh
├── docs/
│   ├── overview.md
│   ├── architecture.md            ← C4 PlantUML diagrams
│   ├── technical.md               ← MSBuild/CLI/package format reference
│   └── engineering.md             ← this file
├── samples/
│   ├── MyApp.Data/                ← EF Core project (entities + DbContext)
│   │   ├── Entities/
│   │   ├── AppDbContext.cs
│   │   ├── DesignTimeContextFactory.cs
│   │   ├── MyApp.Data.csproj
│   │   └── SchemaScript/          ← console app; calls GenerateCreateScript()
│   │       ├── Program.cs
│   │       └── SchemaScript.csproj
│   └── MyApp.Database/            ← .pgpkgproj; produces MyApp.Database-1.0.0.pgpkg
│       ├── MyApp.Database.pgpkgproj
│       └── schema/                ← 001_ef_schema.sql generated here (gitignored)
└── src/
    ├── Cadwell.PgPkg.Sdk/
    │   ├── Sdk/
    │   │   ├── Sdk.props          ← MSBuild SDK entry-point (imported before project)
    │   │   └── Sdk.targets        ← MSBuild SDK entry-point (imported after project)
    │   ├── build/
    │   │   ├── Cadwell.PgPkg.Sdk.props    ← default properties & item globs
    │   │   └── Cadwell.PgPkg.Sdk.targets  ← Build/Clean/CreatePgPkg/CollectPgSchema
    │   └── Cadwell.PgPkg.Sdk.csproj
    ├── Cadwell.PgPkg.Tool/
    │   ├── Program.cs
    │   ├── DeployCommand.cs
    │   ├── DiffCommand.cs
    │   ├── PublishCommand.cs
    │   ├── PgPkgPackage.cs
    │   ├── PgSchemaRunner.cs
    │   └── Cadwell.PgPkg.Tool.csproj
    └── Cadwell.PgPkg.EfTool/
        ├── pgpkg-ef.ps1           ← drives SchemaScript (Windows PowerShell)
        └── pgpkg-ef.sh            ← drives SchemaScript (bash)
```

---

## Building

```powershell
# Build and test the full solution
dotnet build

# Build only the database sample (triggers EF extraction + packaging)
dotnet build samples\MyApp.Database\MyApp.Database.pgpkgproj
```

---

## SDK Development Workflow

When you change `Cadwell.PgPkg.Sdk` source files, you must repack and clear the NuGet cache before consuming projects pick up the changes:

```powershell
# 1. Bump the version in Cadwell.PgPkg.Sdk.csproj and in the sample .pgpkgproj Sdk= attribute

# 2. Repack
dotnet pack src\Cadwell.PgPkg.Sdk\Cadwell.PgPkg.Sdk.csproj -o local-feed --no-build

# 3. Clear the cached version
Remove-Item "$env:USERPROFILE\.nuget\packages\cadwell.pgpkg.sdk\<old-version>" -Recurse -Force

# 4. Rebuild the sample
dotnet build samples\MyApp.Database\MyApp.Database.pgpkgproj
```

> The `local-feed/` directory is gitignored. In CI, use a proper NuGet feed.

---

## Installing the `pgpkg` tool locally

```powershell
dotnet pack src\Cadwell.PgPkg.Tool\Cadwell.PgPkg.Tool.csproj -o local-feed
dotnet tool install --global Cadwell.PgPkg.Tool --add-source .\local-feed
pgpkg --help
```

---

## Running the local Docker stack

```powershell
cd containers
docker compose up -d --wait
# pgAdmin: http://localhost:5050  (admin@pgproj.local / pgadmin)
# Postgres: localhost:5432        (pgadmin / pgadmin)
```

## Running the full end-to-end sample

```powershell
# Starts containers, builds MyApp.Database, deploys via pgpkg
.\containers\deploy-sample.ps1

# Dry-run (show diff without applying)
.\containers\deploy-sample.ps1 -DryRun

# Skip docker up if containers are already running
.\containers\deploy-sample.ps1 -SkipDockerUp
```

---

## Using `pgpkg-ef` manually

If you have an EF Core project with a `SchemaScript` sub-project, use `pgpkg-ef` to stage the SQL outside of the MSBuild build:

```powershell
# Windows
.\src\Cadwell.PgPkg.EfTool\pgpkg-ef.ps1 `
    -Project .\samples\MyApp.Data `
    -DatabaseName myapp `
    -OutputDir .\samples\MyApp.Database\pgpkg-schema
```

```bash
# Linux / macOS
./src/Cadwell.PgPkg.EfTool/pgpkg-ef.sh ./samples/MyApp.Data \
    --database-name myapp \
    --output-dir ./samples/MyApp.Database/pgpkg-schema
```

### SchemaScript pattern

`pgpkg-ef` expects a `SchemaScript` console app alongside the EF project. The app must:

1. Accept the output file path as `args[0]`
2. Build a `DbContext` using `UseNpgsql()`
3. Call `ctx.Database.GenerateCreateScript()`
4. Write the result to `args[0]`

See `samples/MyApp.Data/SchemaScript/Program.cs` for the reference implementation.

---

## Adding a new pgschema command

1. Add a new `XyzCommand.cs` in `Cadwell.PgPkg.Tool/` following the pattern in `DeployCommand.cs`.
2. Register it in `Program.cs`: `rootCommand.AddCommand(XyzCommand.Build());`.
3. Map new options to `pgschema` arguments inside `PgSchemaRunner.RunAsync`.

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| `.pgpkg` = ZIP | Zip is universally supported; no custom binary format to maintain |
| `schema/{dbName}/` layout inside zip | Matches pgschema's `--dir` convention; unzip → point → done |
| `manifest.json` | Machine-readable metadata without coupling to zip file naming |
| EF bridge via `GenerateCreateScript()`, not migrations | Desired-state philosophy — the EF model IS the schema; no migration history dependency |
| `SchemaScript` as a separate console project | Keeps the EF library clean; `GenerateCreateScript()` needs runtime DI which is awkward in MSBuild `Exec` context |
| `pgpkg-ef` as scripts, not a .NET tool | Thin orchestration of existing `dotnet run` — no extra binary to ship |
| Derived SDK props in `Sdk.targets` not `Sdk.props` | `Sdk.props` evaluates before the project file; `Sdk.targets` evaluates after, so it sees user overrides |
| `DefaultTargets="Build"` required in project file | Without `Microsoft.NET.Sdk`, MSBuild uses the first defined target as default; user targets appear before SDK imports |
| `System.CommandLine` beta4 | Stable enough API surface; aligns with Microsoft's direction for .NET CLI tools |
| `Npgsql` included in tool | Reserved for future direct inspection commands |
| MSBuild `ZipDirectory` task | Built into .NET 5+ MSBuild; no third-party zip dependency in the SDK |

---

## Versioning Strategy

Both the SDK and the tool use independent semantic versions.  
Schema packages carry their own `<Version>` independent of tooling versions.

Recommended convention:

```
<Version>{major}.{minor}.{patch}</Version>
```

where `major` bumps on breaking schema changes, `minor` on additive changes, `patch` on fixes/metadata only.

When incrementing the SDK version, remember to update the `Sdk=` attribute in all consuming `.pgpkgproj` files.
