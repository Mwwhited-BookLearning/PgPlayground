# Engineering Guide

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| .NET SDK | 10.0+ | `dotnet --version` |
| pgschema | latest | Install binary; add to PATH or set `PGSCHEMA_PATH` |
| PowerShell | 5.1+ or pwsh | For `pgpkg-ef.ps1` |
| bash | any | For `pgpkg-ef.sh` on Linux/macOS |
| PostgreSQL | 14+ | Target server for integration testing |

---

## Repository Layout

```
PgProj/
├── docs/                          ← you are here
├── samples/
│   └── MyApp.Database/            ← example .pgpkgproj + schema SQL
│       ├── MyApp.Database.pgpkgproj
│       └── schema/001_initial.sql
└── src/
    ├── Cadwell.PgPkg.Sdk/
    │   ├── Sdk/
    │   │   ├── Sdk.props          ← MSBuild SDK entry-point (props)
    │   │   └── Sdk.targets        ← MSBuild SDK entry-point (targets)
    │   ├── build/
    │   │   ├── Cadwell.PgPkg.Sdk.props    ← default properties & item globs
    │   │   └── Cadwell.PgPkg.Sdk.targets  ← CreatePgPkg / CleanPgPkg targets
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
        ├── pgpkg-ef.ps1           ← Windows PowerShell script
        └── pgpkg-ef.sh            ← bash script
```

---

## Building

```powershell
# Build everything
dotnet build

# Build the SDK package
dotnet pack src\Cadwell.PgPkg.Sdk\Cadwell.PgPkg.Sdk.csproj

# Build the tool
dotnet pack src\Cadwell.PgPkg.Tool\Cadwell.PgPkg.Tool.csproj
```

---

## Testing the SDK locally

1. Pack the SDK:
   ```powershell
   dotnet pack src\Cadwell.PgPkg.Sdk\Cadwell.PgPkg.Sdk.csproj -o .\local-feed
   ```

2. Add a `nuget.config` next to your test project pointing at `.\local-feed`.

3. Create a test project:
   ```xml
   <!-- MySchema.pgpkgproj -->
   <Project Sdk="Cadwell.PgPkg.Sdk/1.0.0">
     <PropertyGroup>
       <DatabaseName>testdb</DatabaseName>
       <Version>0.1.0</Version>
     </PropertyGroup>
   </Project>
   ```

4. Drop some `.sql` files in the project directory.

5. `dotnet build` → produces `bin\Debug\net10.0\MySchema-0.1.0.pgpkg`.

---

## Installing the tool locally

```powershell
dotnet pack src\Cadwell.PgPkg.Tool\Cadwell.PgPkg.Tool.csproj -o .\local-feed
dotnet tool install --global Cadwell.PgPkg.Tool --add-source .\local-feed
pgpkg --help
```

---

## Running pgpkg-ef

```powershell
# Windows
.\src\Cadwell.PgPkg.EfTool\pgpkg-ef.ps1 `
    -Project .\path\to\MyApp.Data `
    -DatabaseName myapp `
    -OutputDir .\MyApp.Database\pgpkg-schema
```

```bash
# Linux / macOS
./src/Cadwell.PgPkg.EfTool/pgpkg-ef.sh ./path/to/MyApp.Data \
    --database-name myapp \
    --output-dir ./MyApp.Database/pgpkg-schema
```

Then reference the staged SQL from your `.pgpkgproj`:

```xml
<ItemGroup>
  <PgSchema Include="pgpkg-schema\schema\myapp\**\*.sql" />
</ItemGroup>
```

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
| EF bridge as a script, not a .NET tool | `dotnet ef` already handles the complexity; a thin script avoids duplicating that logic |
| `System.CommandLine` beta4 | Stable enough API surface; aligns with Microsoft's direction for .NET CLI tools |
| `Npgsql` included in tool | Reserved for future direct inspection commands (e.g., read current schema without pgschema) |
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
