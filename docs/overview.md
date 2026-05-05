# PgProj — PostgreSQL Desired-State Deployment

## Business Context

Database change management for PostgreSQL has historically lagged behind SQL Server tooling.  
SQL Server teams use **DACPAC** (Data-Tier Application packages) to declare the *desired state* of a database, diff that state against a live server, and apply only the necessary delta — without writing manual migration scripts.

PgProj brings the same workflow to PostgreSQL by combining:

* **[pgschema](https://github.com/pgschema/pgschema)** — a declarative schema-diff/apply engine for Postgres
* **MSBuild SDK conventions** familiar to every .NET developer
* **A distributable package format** (`.pgpkg`) that travels through CI/CD pipelines the same way NuGet packages do

### Key Business Goals

| Goal | How PgProj Addresses It |
|------|-------------------------|
| Eliminate manual migration bookkeeping | Desired-state SQL is the source of truth; diffs are generated on demand |
| Standardise Postgres deployments across teams | One package format, one deploy command |
| Integrate with .NET build pipelines | First-class MSBuild SDK; builds alongside application code |
| Support EF Core teams | Script extraction utility bridges EF migrations → pgschema format |
| Auditable, versioned schema artefacts | Each build produces a deterministic `.pgpkg` in source control / feed |

---

## Components

| Component | Type | Purpose |
|-----------|------|---------|
| `Cadwell.PgPkg.Sdk` | MSBuild SDK NuGet package | Defines the `.pgpkgproj` project type; produces `.pgpkg` zip artefacts |
| `Cadwell.PgPkg.Tool` (`pgpkg`) | .NET global/local tool | Deploys, diffs, and publishes `.pgpkg` packages |
| `pgpkg-ef` (`.ps1` / `.sh`) | Shell scripts | Extracts an EF Core project's consolidated schema into pgschema-compatible SQL |

See [architecture.md](architecture.md) for the C4 diagrams.  
See [technical.md](technical.md) for engineering details.  
See [engineering.md](engineering.md) for developer setup and contribution guide.
