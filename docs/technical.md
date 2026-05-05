# Technical Reference

## Package Format — `.pgpkg`

A `.pgpkg` file is a standard ZIP archive with a well-known internal layout:

```
manifest.json
schema/
  {databaseName}/
    [recursive SQL / pgschema files]
```

### manifest.json

```json
{
  "databaseName": "myapp",
  "version": "1.0.0",
  "created": "MyApp.Database"
}
```

| Field | Source | Description |
|-------|--------|-------------|
| `databaseName` | `<DatabaseName>` MSBuild property | Logical database identifier used as the schema sub-folder name |
| `version` | `<Version>` MSBuild property | Semantic version of this schema package |
| `created` | `$(MSBuildProjectName)` | Project that produced the package |

---

## MSBuild SDK — `Cadwell.PgPkg.Sdk`

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `DatabaseName` | `$(MSBuildProjectName)` | Logical database name; becomes the sub-folder in the archive |
| `Version` | `1.0.0` | Package version |
| `PgPkgOutputPath` | `$(OutputPath)` | Directory where the `.pgpkg` is written |
| `PgPkgFileName` | `$(MSBuildProjectName)-$(Version).pgpkg` | Output file name |
| `PgPkgFilePath` | derived | Full path to the output package |
| `PgPkgSchemaRoot` | `schema/$(DatabaseName)` | Archive-internal path prefix |

### Items

| Item | Default Glob | Description |
|------|-------------|-------------|
| `PgSchema` | `**\*.sql;**\*.pgschema` | Files staged into the package; preserves `RecursiveDir` inside archive |

### Targets

| Target | Runs After | Description |
|--------|-----------|-------------|
| `CreatePgPkg` | `Build` | Stages files, writes manifest, zips to `.pgpkg`; incremental (input/output tracked) |
| `CleanPgPkg` | `Clean` | Deletes the `.pgpkg` and the intermediate stage directory |
| `GetPgPkgOutputPath` | — | Returns `$(PgPkgFilePath)` for other tooling to consume |

### Intermediate staging

During `CreatePgPkg`, files are first copied to:

```
$(IntermediateOutputPath)pgpkg-stage\schema\{DatabaseName}\...
```

This preserves the original relative directory structure and gives MSBuild a clean tree to zip.

---

## CLI — `pgpkg` (`Cadwell.PgPkg.Tool`)

Built with `System.CommandLine` beta4.

### `pgpkg deploy <package> --connection <connstr> [options]`

1. Extracts the `.pgpkg` to a temp directory
2. Reads `manifest.json`
3. Resolves the schema folder: `schema/{databaseName}/`
4. Invokes `pgschema apply --dir <schemaDir> --db <connstr> [--schema <name>] [--dry-run]`
5. Cleans up the temp directory

Options:

| Option | Description |
|--------|-------------|
| `--connection, -c` | PostgreSQL connection string (required) |
| `--dry-run, -n` | Show planned changes without applying |
| `--schema, -s` | Override the Postgres schema name inside the database |

### `pgpkg diff <package> --connection <connstr>`

Same extraction flow as deploy, but invokes `pgschema diff`.  
Exits non-zero if pgschema reports differences.

### `pgpkg publish <package> --source <path-or-url> [--api-key <key>]`

- **Local directory**: copies the `.pgpkg` file directly.
- **Remote URL**: delegates to `dotnet nuget push` (the `.pgpkg` is treated as an opaque blob by the NuGet protocol).

### pgschema binary resolution

`PgSchemaRunner` searches in order:

1. All directories on `PATH` for `pgschema` / `pgschema.exe`
2. `PGSCHEMA_PATH` environment variable

---

## EF Core Bridge — `pgpkg-ef`

Available as `pgpkg-ef.ps1` (Windows PowerShell) and `pgpkg-ef.sh` (bash).

Both scripts:

1. Resolve the `.csproj` path
2. Run `dotnet ef dbcontext script --output <schemaDir>/001_migrations.sql --no-build [--idempotent]`
3. Print the `<PgSchema Include="...">` snippet to add to the `.pgpkgproj`

The `--idempotent` flag (default on) tells EF to emit `IF NOT EXISTS` guards, making the script safe to replay — matching the desired-state philosophy.

### Workflow when combining EF Core + pgpkg

```
EF Core project   ──(pgpkg-ef)──►  staged SQL files
                                        │
                                        ▼
                               MyApp.Database.pgpkgproj
                                        │
                               dotnet build
                                        │
                                        ▼
                               MyApp.Database-1.0.0.pgpkg
                                        │
                               pgpkg deploy -c $CONN_STR
                                        │
                                        ▼
                                  PostgreSQL server
```

---

## Dependency Versions (as shipped)

| Package | Version | Notes |
|---------|---------|-------|
| `System.CommandLine` | `2.0.0-beta4.22272.1` | CLI framework for `pgpkg` tool |
| `Npgsql` | `9.0.3` | Available for future direct Postgres operations |
| `net10.0` | TFM | All projects target .NET 10 |
