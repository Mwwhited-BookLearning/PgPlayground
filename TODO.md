# TODO

Outstanding work tracked here. Remove items when completed.

---

## Tooling / Infrastructure

- [ ] **SDK versioning script** — Every SDK source change requires: bump version in `.csproj`, repack to `local-feed/`, update `Sdk="Cadwell.PgPkg.Sdk/<version>"` in all consuming `.pgpkgproj` files, and clear the NuGet cache. A helper script (`scripts/pack-sdk.ps1`) or a CI pipeline step would automate this.

- [ ] **CI pipeline** — No GitHub Actions / Azure DevOps workflow exists. Needs at minimum:
  - Build and test on PR
  - Pack SDK + Tool to a NuGet feed on merge to `main`
  - Optionally: run `pgpkg diff` against a test Postgres container

- [ ] **NuGet feed** — `local-feed/` is gitignored and only usable locally. Publish `Cadwell.PgPkg.Sdk` and `Cadwell.PgPkg.Tool` to a real feed (NuGet.org or a private Azure Artifacts / GitHub Packages feed) so teams can consume them without the local workaround.

---

## `Cadwell.PgPkg.Sdk`

- [ ] **SDK version bump automation** — When SDK MSBuild files change, the NuGet package version must be bumped. Currently manual. Consider a `Directory.Build.props` or a versioning convention.

- [ ] **`Rebuild` target wiring** — `Rebuild` calls `Clean;Build` but `Clean` deletes `$(PgPkgFilePath)` using the property value at load time. Verify this correctly deletes the old `.pgpkg` when `Version` or `DatabaseName` change between builds.

- [ ] **Incremental build** — `CreatePgPkg` currently always runs (no `Inputs`/`Outputs`). Adding incremental tracking (e.g. a sentinel file or hashing `@(PgSchema)`) would speed up large projects.

---

## `Cadwell.PgPkg.Tool`

- [ ] **`pgpkg publish` — NuGet protocol compatibility** — The current implementation delegates to `dotnet nuget push`. NuGet feeds may reject `.pgpkg` files as an unknown extension. Evaluate whether wrapping the package inside a `.nupkg` envelope (or using a dedicated feed format) is needed.

- [ ] **pgschema version pinning** — `PgSchemaRunner` resolves pgschema from `PATH` or `PGSCHEMA_PATH`. There is no version check or minimum-version guard. A `pgschema --version` pre-flight check would surface incompatible installs early.

- [ ] **Integration tests** — No automated tests. Needs a test project that spins up a Postgres container (Testcontainers), applies a `.pgpkg`, and asserts the schema was created correctly.

---

## Samples

- [ ] **`DesignTimeContextFactory` cleanup** — `samples/MyApp.Data/DesignTimeContextFactory.cs` was originally needed for `dotnet ef` tooling. Now that we use `GenerateCreateScript()` instead of migrations it serves no functional purpose. Decide whether to keep it (useful if someone adds `dotnet ef` tooling later) or remove it.

- [ ] **Second migration sample** — Add a `002_add_audit_columns.sql` (or a second EF entity) to demonstrate what a schema evolution looks like in the desired-state model — i.e., modify the EF model, rebuild, and show `pgpkg diff` output before and after.

---

## Documentation

- [ ] **pgschema installation guide** — The docs reference pgschema but do not explain how to install it (there is no `dotnet tool install` for it; it is a Go binary). Add installation steps to `engineering.md`.

- [ ] **Package feed setup guide** — `engineering.md` references a "proper NuGet feed" for CI but does not explain how to configure one. Add a section for GitHub Packages or Azure Artifacts.
