# PgProj — Claude context

## Project overview

PgProj is a .NET 10 SDK + CLI toolchain that brings DACPAC-style desired-state database deployments to PostgreSQL using the `pgschema` Go binary.

**Components:**
- `Cadwell.PgPkg.Sdk` — MSBuild SDK NuGet package defining the `.pgpkgproj` project type; outputs a `.pgpkg` ZIP with layout `schema/{databaseName}/`
- `Cadwell.PgPkg.Tool` (`pgpkg` CLI) — dotnet global tool; `deploy`, `diff`, `publish` commands wrapping pgschema
- `pgpkg-ef` (`src/Cadwell.PgPkg.EfTool/pgpkg-ef.ps1` + `.sh`) — thin scripts that build and run a `SchemaScript` console app to call `DbContext.GenerateCreateScript()`; no EF migrations involved

**Why:** Fills the gap between SQL Server's DACPAC tooling and Postgres; integrates with standard .NET build pipelines.

## Key design decisions

- `.pgpkg` is a plain ZIP — `ZipDirectory` MSBuild task, no third-party zip dependency
- Desired-state via `GenerateCreateScript()` not migrations — the EF model IS the schema
- `SchemaScript` pattern — small console app alongside the EF project; instantiates `DbContext` with a dummy connection string and writes DDL to a file path passed as `args[0]`
- Derived SDK properties (`PgPkgFilePath`, `PgPkgSchemaRoot`, etc.) live in `Sdk.targets` not `Sdk.props` — `Sdk.props` evaluates before the project file so user overrides (e.g. `<DatabaseName>`) aren't visible there yet
- `DefaultTargets="Build"` is required on `.pgpkgproj` — without `Microsoft.NET.Sdk`, MSBuild defaults to the first defined target; user targets appear before SDK imports and would become the entry point otherwise
- `Clean` globs `*.pgpkg` in the output dir to remove stale packages from version/name changes
- `CreatePgPkg` uses `Inputs="@(PgSchema);$(MSBuildProjectFullPath)"` / `Outputs="$(PgPkgFilePath)"` for incremental builds
- Static `<PgSchema Include="..." Condition="Exists(...)">` pattern in `.pgpkgproj` enables timestamp tracking of generated SQL across builds

## SDK development workflow

```powershell
# Bump version, repack, clear cache, update all .pgpkgproj Sdk= attributes
.\scripts\pack-sdk.ps1 -Version 1.x.x
```

NuGet SDK resolver requires version in `Sdk="Cadwell.PgPkg.Sdk/x.y.z"`. Local feed is at `local-feed/` (gitignored); `nuget.config` points to it.

## Containers / local dev

- `containers/.env.example` — copy to `containers/.env` to override credentials
- `containers/deploy-sample.ps1` (or `.sh`) — loads `.env`, regenerates `pgadmin/pgpass` and `pgadmin/servers.json`, starts Docker stack, builds + deploys the sample package
- pgAdmin default: `admin@pgproj.local` / `admin` at `http://localhost:5050`
- Postgres default: `admin`/`admin` at `localhost:5432`
- pgAdmin auto-connects via `servers.json` + `pgpass` (entrypoint chmod 600 applied at container start)

## User preferences

- No EF migrations — use `DbContext.GenerateCreateScript()` only
- Scripts over .NET tools for thin orchestration (pgpkg-ef)
- No comments in code unless the WHY is non-obvious
- Terse responses; no trailing summaries
- Memory lives here in `CLAUDE.md`, not in `~/.claude/projects/.../memory/`
