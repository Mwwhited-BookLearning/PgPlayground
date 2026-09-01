# Architecture

All diagrams use [PlantUML](https://plantuml.com) with [C4-PlantUML](https://github.com/plantuml-stdlib/C4-PlantUML) macros.

---

## Level 1 — System Context

```plantuml
@startuml C4_Context
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

title PgProj — System Context

Person(dev, "Developer / CI Agent", "Writes schema SQL or uses EF Core")
System(pgproj, "PgProj Toolchain", "Builds, packages, and deploys PostgreSQL desired-state schemas")
System_Ext(postgres, "PostgreSQL Server", "Target database server")
System_Ext(nuget, "NuGet / Package Feed", "Stores versioned .pgpkg artefacts")
System_Ext(pgschema, "pgschema binary", "Open-source declarative schema diff/apply engine")
System_Ext(efcore, "EF Core DbContext", "Provides GenerateCreateScript() DDL at build time")

Rel(dev,      pgproj,   "Builds & deploys schemas using")
Rel(pgproj,   postgres, "Applies schema changes to")
Rel(pgproj,   nuget,    "Publishes .pgpkg packages to")
Rel(pgproj,   pgschema, "Delegates diff/apply to")
Rel(pgproj,   efcore,   "Optionally extracts desired-state DDL via")

@enduml
```

---

## Level 2 — Container Diagram

```plantuml
@startuml C4_Container
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

title PgProj — Containers

Person(dev, "Developer / CI Agent")

System_Boundary(pgproj, "PgProj Toolchain") {
    Container(sdk,          "OoBDev.PgPkg.Sdk",   "MSBuild SDK (NuGet)",   "Defines .pgpkgproj project type; zips schema files into .pgpkg during dotnet build")
    Container(tool,         "OoBDev.PgPkg.Tool",  ".NET Tool (pgpkg CLI)", "deploy / diff / publish commands")
    Container(eftool,       "pgpkg-ef",            "Shell Script (ps1/sh)", "Drives SchemaScript to extract GenerateCreateScript() DDL from any EF DbContext")
    Container(schemaScript, "SchemaScript",        ".NET Console App",      "Thin wrapper: builds DbContext, calls GenerateCreateScript(), writes SQL file")
}

System_Ext(postgres, "PostgreSQL Server")
System_Ext(nuget,    "Package Feed")
System_Ext(pgschema, "pgschema binary")
System_Ext(efcore,   "EF Core DbContext")

Rel(dev,          sdk,          "Authors .pgpkgproj; runs dotnet build")
Rel(dev,          tool,         "Runs pgpkg deploy/diff/publish")
Rel(dev,          eftool,       "Runs pgpkg-ef to extract EF schema")

Rel(sdk,          nuget,        "Produces .pgpkg artefact")
Rel(tool,         pgschema,     "Shells out to pgschema apply/diff")
Rel(tool,         postgres,     "Targets for schema changes (via pgschema)")
Rel(tool,         nuget,        "Publishes .pgpkg via dotnet nuget push")
Rel(eftool,       schemaScript, "Builds and runs")
Rel(schemaScript, efcore,       "Instantiates DbContext, calls GenerateCreateScript()")
Rel(schemaScript, sdk,          "Produces SQL files consumed by .pgpkgproj")

@enduml
```

---

## Level 3 — Component: OoBDev.PgPkg.Tool

```plantuml
@startuml C4_Component_Tool
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

title OoBDev.PgPkg.Tool — Components

Container_Boundary(tool, "OoBDev.PgPkg.Tool (pgpkg CLI)") {
    Component(prog,    "Program",         "Top-level command registration")
    Component(deploy,  "DeployCommand",   "Extracts .pgpkg, invokes pgschema apply")
    Component(diff,    "DiffCommand",     "Extracts .pgpkg, invokes pgschema diff")
    Component(publish, "PublishCommand",  "Copies/pushes .pgpkg to feed or directory")
    Component(pkg,     "PgPkgPackage",    "Unzips .pgpkg, reads manifest.json")
    Component(runner,  "PgSchemaRunner",  "Resolves and shells out to pgschema binary")
}

System_Ext(pgschema, "pgschema binary")
System_Ext(postgres, "PostgreSQL Server")
System_Ext(nuget,    "Package Feed")

Rel(prog,    deploy,  "registers")
Rel(prog,    diff,    "registers")
Rel(prog,    publish, "registers")
Rel(deploy,  pkg,     "uses")
Rel(diff,    pkg,     "uses")
Rel(deploy,  runner,  "uses")
Rel(diff,    runner,  "uses")
Rel(runner,  pgschema,"execs")
Rel(pgschema,postgres,"connects to")
Rel(publish, nuget,   "pushes to")

@enduml
```

---

## Level 3 — Component: MSBuild SDK Build Pipeline

```plantuml
@startuml C4_Component_SDK
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

title OoBDev.PgPkg.Sdk — MSBuild Target Flow

Container_Boundary(sdk, "MSBuild build of a .pgpkgproj") {
    Component(build,          "Build target",          "Entry point — DependsOnTargets: CreatePgPkg")
    Component(collect,        "CollectPgSchema target","Extension seam — BeforeTargets hooks add to @(PgSchema)")
    Component(extract,        "ExtractEfSchema target","Project-level — BeforeTargets: CollectPgSchema; runs SchemaScript")
    Component(create,         "CreatePgPkg target",    "Stages files, writes manifest.json, zips to .pgpkg")
}

Rel(build,    create,   "DependsOnTargets")
Rel(create,   collect,  "DependsOnTargets")
Rel(extract,  collect,  "BeforeTargets (runs first)")

@enduml
```

---

## .pgpkg Package Structure

```
myapp-1.0.0.pgpkg  (ZIP)
├── manifest.json              ← { databaseName, version, created }
└── schema/
    └── {databaseName}/
        ├── 001_schema.sql     ← desired-state DDL (from EF GenerateCreateScript or hand-authored)
        └── ...                ← preserves relative sub-directory structure
```

The `schema/{databaseName}/` layout mirrors what pgschema's `--dir` flag expects, so the tool only needs to unzip and point pgschema at the folder.

---

## EF Core Desired-State Extraction Flow

```
EF Core project
  └── SchemaScript (console app)
        └── DbContext.GenerateCreateScript()
              │
              ▼
        001_schema.sql  (desired-state DDL)
              │
              ▼  (picked up by ExtractEfSchema MSBuild target)
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
        pgschema apply
              │
              ▼
        PostgreSQL Server
```
