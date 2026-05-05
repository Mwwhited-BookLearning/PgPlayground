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

### Important: `DefaultTargets="Build"` is required

Projects using this SDK **must** set `DefaultTargets="Build"` on the `<Project>` element:

```xml
<Project Sdk="Cadwell.PgPkg.Sdk/1.0.0" DefaultTargets="Build">
```

Without it, MSBuild will use the first target defined in the project file (typically a custom user target like `ExtractEfSchema`) as the entry point instead of `Build`. This is a consequence of not importing `Microsoft.NET.Sdk` — the standard SDK sets this up implicitly.

### Properties

| Property | Default | Evaluated in | Description |
|----------|---------|-------------|-------------|
| `DatabaseName` | `$(MSBuildProjectName)` | `Sdk.props` | Logical database name; becomes the sub-folder in the archive |
| `Version` | `1.0.0` | `Sdk.props` | Package version |
| `Configuration` | `Debug` | `Sdk.props` | Build configuration |
| `OutputPath` | `bin\$(Configuration)\` | `Sdk.props` | Output directory for the `.pgpkg` file |
| `IntermediateOutputPath` | `obj\$(Configuration)\` | `Sdk.props` | Intermediate staging directory |
| `PgPkgOutputPath` | `$(OutputPath)` | `Sdk.targets` | Directory where the `.pgpkg` is written |
| `PgPkgFileName` | `$(MSBuildProjectName)-$(Version).pgpkg` | `Sdk.targets` | Output file name |
| `PgPkgFilePath` | derived | `Sdk.targets` | Full path to the output package |
| `PgPkgSchemaRoot` | `schema/$(DatabaseName)` | `Sdk.targets` | Archive-internal path prefix |

> **Why are derived properties in `Sdk.targets` and not `Sdk.props`?**  
> `Sdk.props` is evaluated before the project file's own `<PropertyGroup>` blocks.
> If `PgPkgSchemaRoot` were defined there, it would capture `$(DatabaseName)` before the
> user's `<DatabaseName>myapp</DatabaseName>` override is applied.
> `Sdk.targets` evaluates after the project file, so it sees the final resolved values.

### Items

| Item | Default Glob | Description |
|------|-------------|-------------|
| `PgSchema` | `**\*.sql;**\*.pgschema` | Files staged into the package; preserves `RecursiveDir` inside archive |

Set `EnableDefaultPgSchemaItems=false` to disable the default glob (e.g. when a target generates the schema files dynamically).

### Targets

| Target | Called By | Description |
|--------|-----------|-------------|
| `Build` | Default entry point | Depends on `CreatePgPkg` |
| `Rebuild` | Explicit | Runs `Clean` then `Build` |
| `CollectPgSchema` | `CreatePgPkg` (via DependsOnTargets) | Extension seam; other targets use `BeforeTargets="CollectPgSchema"` to inject dynamically-generated files into `@(PgSchema)` |
| `CreatePgPkg` | `Build` (via DependsOnTargets) | Stages files, writes manifest, zips to `.pgpkg` |
| `Clean` | Explicit | Deletes the `.pgpkg` and the intermediate stage directory |
| `GetPgPkgOutputPath` | Tooling | Returns `$(PgPkgFilePath)` |

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

### Design: no migrations

`pgpkg-ef` drives a `SchemaScript` console app — a thin wrapper around `DbContext.GenerateCreateScript()` — rather than using `dotnet ef migrations`. This produces a single, complete desired-state SQL file that reflects the current EF model without any migration history dependency.

### SchemaScript pattern

```csharp
// SchemaScript/Program.cs
var opts = new DbContextOptionsBuilder<AppDbContext>()
    .UseNpgsql("Host=localhost;Database=design_time_only")
    .Options;
await using var ctx = new AppDbContext(opts);
var sql = ctx.Database.GenerateCreateScript();
await File.WriteAllTextAsync(args[0], sql);
```

No connection to a real database is made; the Npgsql provider generates DDL from the EF model metadata alone.

### Workflow when combining EF Core + pgpkg

```
EF Core project
  └── SchemaScript  ──(pgpkg-ef or ExtractEfSchema target)──►  001_schema.sql
                                                                      │
                                                           MyApp.Database.pgpkgproj
                                                                      │
                                                              dotnet build
                                                                      │
                                                              *.pgpkg artefact
                                                                      │
                                                           pgpkg deploy -c $CONN_STR
                                                                      │
                                                            PostgreSQL server
```

### Integrating directly into the MSBuild build

Rather than running `pgpkg-ef` manually, the `ExtractEfSchema` target in a `.pgpkgproj` achieves the same result automatically on every `dotnet build`:

```xml
<Target Name="ExtractEfSchema" BeforeTargets="CollectPgSchema">
  <Exec Command="dotnet build &quot;$(SchemaScriptProject)&quot;" />
  <Exec Command="dotnet run --project &quot;$(SchemaScriptProject)&quot; --no-build -- &quot;$(OutputSqlFile)&quot;" />
  <ItemGroup>
    <PgSchema Include="$(OutputSqlFile)" />
  </ItemGroup>
</Target>
```

---

## Dependency Versions (as shipped)

| Package | Version | Notes |
|---------|---------|-------|
| `System.CommandLine` | `2.0.0-beta4.22272.1` | CLI framework for `pgpkg` tool |
| `Npgsql` | `9.0.3` | Available for future direct Postgres operations |
| `Microsoft.EntityFrameworkCore` | `9.0.4` | Sample EF project |
| `Npgsql.EntityFrameworkCore.PostgreSQL` | `9.0.4` | Sample EF project |
| `net10.0` | TFM | All projects target .NET 10 |
