# PgProj — PostgreSQL Desired-State Deployment

PgProj brings **DACPAC-style desired-state database deployments** to PostgreSQL.
Declare what your database should look like, build a `.pgpkg` package, and deploy it — pgschema computes and applies only the delta.

```
dotnet build MyApp.Database.pgpkgproj   # → MyApp.Database-1.0.0.pgpkg
pgpkg deploy MyApp.Database-1.0.0.pgpkg --connection "Host=...;Database=myapp"
```

## Components

| Component | Description |
|-----------|-------------|
| **`Cadwell.PgPkg.Sdk`** | MSBuild SDK. Author a `.pgpkgproj`, run `dotnet build`, get a `.pgpkg` zip. |
| **`Cadwell.PgPkg.Tool`** (`pgpkg`) | .NET global tool. `deploy`, `diff`, and `publish` commands backed by [pgschema](https://github.com/pgschema/pgschema). |
| **`pgpkg-ef`** (`.ps1` / `.sh`) | Shell scripts that extract a desired-state schema from any EF Core `DbContext` via `GenerateCreateScript()` — no migrations required. |

## Quick Start

### 1. Create a database project

```xml
<!-- MyApp.Database.pgpkgproj -->
<Project Sdk="Cadwell.PgPkg.Sdk/1.0.0" DefaultTargets="Build">
  <PropertyGroup>
    <DatabaseName>myapp</DatabaseName>
    <Version>1.0.0</Version>
  </PropertyGroup>
</Project>
```

Drop `.sql` or `.pgschema` files alongside it — they are included automatically.

### 2. Build the package

```bash
dotnet build MyApp.Database.pgpkgproj
# → bin/Debug/MyApp.Database-1.0.0.pgpkg
```

### 3. Deploy

```bash
pgpkg deploy bin/Debug/MyApp.Database-1.0.0.pgpkg \
  --connection "Host=localhost;Database=myapp;Username=myapp;Password=myapp"
```

### Dry-run diff

```bash
pgpkg diff bin/Debug/MyApp.Database-1.0.0.pgpkg --connection "..."
```

## EF Core Integration

If your schema lives in an EF Core `DbContext`, use the `SchemaScript` pattern — a tiny console app that calls `DbContext.GenerateCreateScript()` and writes the DDL. Wire it into the build with an MSBuild target:

```xml
<Target Name="ExtractEfSchema" BeforeTargets="CollectPgSchema">
  <Exec Command="dotnet build &quot;$(SchemaScriptProject)&quot;" />
  <Exec Command="dotnet run --project &quot;$(SchemaScriptProject)&quot; --no-build -- &quot;$(OutputSqlFile)&quot;" />
  <ItemGroup>
    <PgSchema Include="$(OutputSqlFile)" />
  </ItemGroup>
</Target>
```

See [`samples/MyApp.Data`](samples/MyApp.Data) for a working example and [`samples/MyApp.Database`](samples/MyApp.Database) for the corresponding database project.

## Local Development

```powershell
# Start Postgres + pgAdmin
cd containers && docker compose up -d --wait

# Build, extract schema, package, and deploy in one step
.\containers\deploy-sample.ps1
```

pgAdmin is available at **http://localhost:5050** (`admin@pgproj.local` / `pgadmin`).

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/overview.md](docs/overview.md) | Business context and goals |
| [docs/architecture.md](docs/architecture.md) | C4 PlantUML diagrams (context, container, component) |
| [docs/technical.md](docs/technical.md) | MSBuild properties/targets reference, CLI commands, package format spec |
| [docs/engineering.md](docs/engineering.md) | Developer setup, local testing steps, design decisions |

## Prerequisites

- .NET 10 SDK
- [pgschema](https://github.com/pgschema/pgschema) on `PATH` (or `PGSCHEMA_PATH` env var)
- Docker Desktop (for the sample stack)
