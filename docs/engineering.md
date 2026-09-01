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

## Installing pgschema

pgschema is a Go binary distributed as a standalone release — it is not a .NET tool. It must be on `PATH` or pointed to via the `PGSCHEMA_PATH` environment variable.

> **Windows note:** pgschema does not publish Windows native binaries. Use [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) and install pgschema inside the Linux environment. The `pgpkg` tool reads `PGSCHEMA_PATH` so you can point it at the WSL binary if needed.

### macOS

```bash
brew install pgschema
pgschema --version
```

### Linux

**Option A — Go toolchain (recommended if Go is already installed):**

```bash
go install github.com/pgschema/pgschema@latest
# Binary is placed in $(go env GOPATH)/bin — ensure that is on PATH
```

**Option B — Pre-built release binary:**

```bash
# Replace <version> and <arch> (e.g. 0.1.0, linux_amd64)
curl -sSL https://github.com/pgschema/pgschema/releases/download/v<version>/pgschema_<version>_linux_<arch>.tar.gz \
  | tar -xz pgschema
sudo mv pgschema /usr/local/bin/
pgschema --version
```

### WSL2 (Windows users)

1. Install a WSL2 distribution (Ubuntu 22.04 recommended).
2. Follow the Linux instructions above inside WSL.
3. Call `pgpkg` commands from a WSL shell, or set `PGSCHEMA_PATH` in Windows to the WSL binary path:
   ```powershell
   $env:PGSCHEMA_PATH = "wsl pgschema"
   ```

### Verifying the installation

```bash
pgschema --version
# Expected: pgschema version X.Y.Z
```

The `pgpkg` tool runs a version pre-flight check on every `deploy`/`diff`/`publish` invocation. It will fail fast with a clear message if pgschema is missing or below the minimum required version.

---

## Repository Layout

```
PgProj/
├── .gitignore
├── .gitattributes
├── nuget.config                   ← points at local-feed/ for SDK development
├── local-feed/                    ← packed NuGet packages (not committed — see .gitignore)
├── containers/
│   ├── docker-compose.yml         ← Postgres 18 + pgAdmin 4
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
    ├── OoBDev.PgPkg.Sdk/
    │   ├── Sdk/
    │   │   ├── Sdk.props          ← MSBuild SDK entry-point (imported before project)
    │   │   └── Sdk.targets        ← MSBuild SDK entry-point (imported after project)
    │   ├── build/
    │   │   ├── OoBDev.PgPkg.Sdk.props    ← default properties & item globs
    │   │   └── OoBDev.PgPkg.Sdk.targets  ← Build/Clean/CreatePgPkg/CollectPgSchema
    │   └── OoBDev.PgPkg.Sdk.csproj
    ├── OoBDev.PgPkg.Tool/
    │   ├── Program.cs
    │   ├── DeployCommand.cs
    │   ├── DiffCommand.cs
    │   ├── PublishCommand.cs
    │   ├── PgPkgPackage.cs
    │   ├── PgSchemaRunner.cs
    │   └── OoBDev.PgPkg.Tool.csproj
    └── OoBDev.PgPkg.EfTool/
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

When you change `OoBDev.PgPkg.Sdk` source files, you must repack and clear the NuGet cache before consuming projects pick up the changes:

```powershell
# 1. Bump the version in OoBDev.PgPkg.Sdk.csproj and in the sample .pgpkgproj Sdk= attribute

# 2. Repack
dotnet pack src\OoBDev.PgPkg.Sdk\OoBDev.PgPkg.Sdk.csproj -o local-feed --no-build

# 3. Clear the cached version
Remove-Item "$env:USERPROFILE\.nuget\packages\oobdev.pgpkg.sdk\<old-version>" -Recurse -Force

# 4. Rebuild the sample
dotnet build samples\MyApp.Database\MyApp.Database.pgpkgproj
```

> The `local-feed/` directory is gitignored. In CI, use a proper NuGet feed.

---

## Installing the `pgpkg` tool locally

```powershell
dotnet pack src\OoBDev.PgPkg.Tool\OoBDev.PgPkg.Tool.csproj -o local-feed
dotnet tool install --global OoBDev.PgPkg.Tool --add-source .\local-feed
pgpkg --help
```

---

## Configuring a NuGet package feed

`local-feed/` is gitignored and only usable on the machine where you ran `pack-sdk.ps1`. For team use or CI, publish `OoBDev.PgPkg.Sdk` and `OoBDev.PgPkg.Tool` to a real NuGet feed.

### GitHub Packages

**1. Add the feed to `nuget.config`:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="github" value="https://nuget.pkg.github.com/<org>/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <github>
      <add key="Username" value="%GITHUB_ACTOR%" />
      <add key="ClearTextPassword" value="%NUGET_AUTH_TOKEN%" />
    </github>
  </packageSourceCredentials>
</configuration>
```

Replace `<org>` with your GitHub organisation or username.

**2. Publish from the release workflow:**

The `.github/workflows/release.yml` workflow already does this on `v*` tags:

```yaml
- name: Publish SDK
  run: dotnet nuget push local-feed/OoBDev.PgPkg.Sdk.*.nupkg --source github --api-key ${{ secrets.GITHUB_TOKEN }}
```

**3. Consume in a project:**

Add the feed to the consuming project's `nuget.config` and set the `NUGET_AUTH_TOKEN` environment variable (or a Personal Access Token with `read:packages` scope) before running `dotnet restore`.

```powershell
$env:NUGET_AUTH_TOKEN = "ghp_..."
dotnet restore
```

### Azure Artifacts

**1. Install the credential provider:**

```powershell
iex "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) }"
```

**2. Add the feed to `nuget.config`:**

```xml
<packageSources>
  <add key="azure" value="https://pkgs.dev.azure.com/<org>/_packaging/<feed>/nuget/v3/index.json" />
</packageSources>
```

**3. Authenticate and push:**

```bash
dotnet nuget push local-feed/OoBDev.PgPkg.Sdk.*.nupkg \
  --source azure \
  --api-key az
```

The Azure Artifacts credential provider handles authentication interactively or via the `SYSTEM_ACCESSTOKEN` variable in Azure Pipelines.

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
.\src\OoBDev.PgPkg.EfTool\pgpkg-ef.ps1 `
    -Project .\samples\MyApp.Data `
    -DatabaseName myapp `
    -OutputDir .\samples\MyApp.Database\pgpkg-schema
```

```bash
# Linux / macOS
./src/OoBDev.PgPkg.EfTool/pgpkg-ef.sh ./samples/MyApp.Data \
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

1. Add a new `XyzCommand.cs` in `OoBDev.PgPkg.Tool/` following the pattern in `DeployCommand.cs`.
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
