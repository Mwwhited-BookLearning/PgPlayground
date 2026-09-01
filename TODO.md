# TODO

Outstanding work tracked here. Remove items when completed.

---

## Tooling / Infrastructure

- [x] **SDK versioning script** — `scripts/pack-sdk.ps1` and `scripts/pack-sdk.sh` automate the full cycle: bump version in `.csproj`, repack to `local-feed/`, clear NuGet cache, update `Sdk=` attribute in all consuming `.pgpkgproj` files.

- [x] **CI pipeline** — `.github/workflows/ci.yml` (build + verify on PR/push) and `.github/workflows/release.yml` (pack + publish to GitHub Packages on `v*` tags) are in place.

- [ ] **NuGet feed** — `local-feed/` is gitignored and only usable locally. Publishing `OoBDev.PgPkg.Sdk` and `OoBDev.PgPkg.Tool` to a real feed (NuGet.org or GitHub Packages / Azure Artifacts) requires credentials not available in this repo. See `docs/engineering.md` for setup instructions.

---

## `OoBDev.PgPkg.Sdk`

- [x] **SDK version bump automation** — Handled by `scripts/pack-sdk.ps1` / `pack-sdk.sh` and centralised in `Directory.Build.props`.

- [x] **`Rebuild` target wiring** — `Clean` now globs `$(PgPkgOutputPath)*.pgpkg` so stale packages from version or database-name changes are removed before the next build.

- [x] **Incremental build** — `CreatePgPkg` now declares `Inputs="@(PgSchema);$(MSBuildProjectFullPath)"` and `Outputs="$(PgPkgFilePath)"`. MSBuild skips the zip step when no schema files have changed. The static `<PgSchema Include="..." Condition="Exists(...)">` pattern in `MyApp.Database.pgpkgproj` enables correct timestamp tracking across builds.

---

## `OoBDev.PgPkg.Tool`

- [ ] **`pgpkg publish` — NuGet protocol compatibility** — The current implementation delegates to `dotnet nuget push`. NuGet feeds may reject `.pgpkg` files as an unknown extension. Evaluate whether wrapping the package inside a `.nupkg` envelope (or using a dedicated feed format) is needed.

- [x] **pgschema version pinning** — `PgSchemaRunner.VerifyVersionAsync` runs `pgschema --version` before every command, parses the version with a regex, and throws `InvalidOperationException` if it is below `MinimumVersion` (currently `1.0.0`).

- [ ] **Integration tests** — No automated tests. Needs a test project that spins up a Postgres container (Testcontainers), applies a `.pgpkg`, and asserts the schema was created correctly.

---

## Samples

- [x] **`DesignTimeContextFactory` cleanup decision** — Kept as-is; it provides a convenient hook for anyone who adds `dotnet ef` tooling to the sample later and costs nothing to keep.

- [x] **Second entity sample** — `AuditLog` entity added to `MyApp.Data` (table `audit_logs`, FK to `users`, composite index on `(table_name, record_id)`, index on `occurred_at`). Demonstrates schema evolution in the desired-state model.

---

## Documentation

- [x] **pgschema installation guide** — Added to `docs/engineering.md`: macOS (`brew install pgschema`), Linux (Go toolchain or pre-built release binary), WSL2 for Windows users.

- [x] **Package feed setup guide** — Added to `docs/engineering.md`: GitHub Packages (`nuget.config` with `NUGET_AUTH_TOKEN`) and Azure Artifacts (credential provider + `SYSTEM_ACCESSTOKEN`).
