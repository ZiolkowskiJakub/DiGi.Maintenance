---
name: coding-deployed-webapi
description: Use when verifying a client or server change against the live WebAPI at api.digiproject.uk - swagger as the source of truth, the county to reference to building GET test recipe, access rules and gotchas. Manual curl checks only, never added to DiGi.Test.
---

# Coding — Deployed WebAPI (Live Endpoint Testing)

Directives for manual, on-demand testing against live production endpoints (`https://api.digiproject.uk`). **Do NOT add these tests to `DiGi.Test` or automated test suites.**

---

## 1. Endpoints & Swagger Caveats

- **Base URL:** `https://api.digiproject.uk` (root `/` returns HTTP 404).
- **Swagger JSON:** `https://api.digiproject.uk/swagger/v1/swagger.json`.
- **Diagnostic Suite (`InformationController`):**
  - `GET /information/health` — liveness/readiness probe (`Status`, `ServerTimeUtc`, `Uptime`, `ProcessId`).
  - `GET /information/version` — multi-tier version audit (Host & `DiGi.WebAPI` versions, git commits, CLR runtime).
  - `GET /information/controllers` — deployed controller list, assembly metadata, and route prefixes.
  - `GET /information/endpoints` — full catalog of registered routes, HTTP verbs, and parameter contracts. Pass `?includeignored=true` to inspect write/internal endpoints hidden from Swagger.
  - `GET /information/assemblies` — inventory of loaded assemblies in `AssemblyLoadContext` (verifying dynamic `extensions/` plugins).
  - `GET /information/system` — safe process telemetry (working set memory, GC heap, thread pool threads, OS version).

### Swagger Contract Limitations
1. **Incomplete Endpoint List:** Base `WebAPIController` sets `[ApiExplorerSettings(IgnoreApi = true)]`. Write endpoints (`updateitem(s)`), `user/*`, and several `item*` reads are omitted from Swagger. Query `GET /information/endpoints?includeignored=true` or `GET /information/controllers` to discover all active endpoints.
2. **Schema Inaccuracies:** Wire format uses **PascalCase property names**, a mandatory `_type` discriminator (`"Namespace.Type,ShortAssembly"`), and **integer enums**. Ignore Swagger schema camelCase/string-enum definitions.

### The Deployed Build Lags the Repository

> **A 404 usually means "not deployed yet", not "wrong URL".** The host is on its own release cadence, so an endpoint that exists in source may not be running.

`GET /information/controllers` and `GET /information/version` return `InformationalVersion` per assembly carrying the **commit hash** — compare it against `git log` for the controller you need before concluding anything from a 404. Worked example, 2026-08-21: the host served `DiGi.GIS.WebAPI` 0.8.7 / commit `e6dd012`, so `idsbycode`, `administrativeareal2Dreferencesbyids`, `building2d/referenceuniquenesssummary` and all five `gis/terrain` diagnostics (`countbycountyid`, `summariesbycountyids`, `densitiesbycountyids`, `coveragebycountyid`, `gapsbyboundingbox`) answered 404 while sitting committed in the repo. The terrain **mesh** endpoints, committed earlier, were live.

Distinguish "route absent" from "no data" by asking for something that certainly exists: `idsbycode?code=1465&administrativearealtype=2` returned 404 while `idbycode` on the same code returned `55417`, which is route-absent, not data-absent.

Writing a client against an endpoint that is not live yet is covered in [Coding - WebAPI Contracts.md](Coding%20-%20WebAPI%20Contracts.md) §4.

---

## 2. Remote Server Investigation Workflow for AI Models & Developers

AI models investigating a live, staging, or local WebAPI instance must use either `InvestigateServer.ps1` or direct `curl.exe` commands.

### Tiered Access & Authorization Model (`WebAPI_Diagnostics.conf`)
Diagnostic endpoints follow a **Tiered Access** model configured via `user files/WebAPI_Diagnostics.conf`:
- **Public Tier (No key required)**: `GET /information/health`, `GET /information/version` (without commit hashes), and standard `GET /information/endpoints` (`includeignored=false`).
- **Protected Tier (Guarded by the `key` request header)**: `GET /information/system`, `GET /information/assemblies`, `GET /information/controllers`, `GET /information/endpoints?includeignored=true`, and the commit hashes on `GET /information/version`. Access is **denied by default**: a missing or unreadable configuration, `Enabled=false`, a blank configured key or a missing header all return **HTTP 401 Unauthorized**.
- The key travels in the `key` **request header**, never in the query string - a query string is written to server access logs, `Referer` headers and shell history.

### Deployment & Sync (`SyncDirectories.ps1` & `CopyUserFiles`)
`WebAPI_Diagnostics.conf` resides in `user files/` (git-ignored). `DiGi.WebAPI.WindowsService.csproj` defines a `CopyUserFiles` MSBuild target that copies `user files/**` to `bin/` upon compilation. When `SyncDirectories.ps1` runs, it automatically synchronizes `bin/` to the target `SOFTWARE_DIRECTORY\DiGi.WebAPI.WindowsService`.

### Automated Investigation Script (`InvestigateServer.ps1`)
Run the script to inspect the server in a single token-efficient step:
```powershell
# Complete server diagnostics (Health, Version, System, Controllers)
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/InvestigateServer.ps1" -All

# Target protected telemetry using diagnostic key
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/InvestigateServer.ps1" -All -Key "your_key"
# (omit -Key entirely to read it from 'user files/WebAPI_Diagnostics.conf')

# Discover all registered routes including internal/write endpoints
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/InvestigateServer.ps1" -Endpoints -IncludeIgnored -Key "your_key"

# Filter endpoints by controller
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/InvestigateServer.ps1" -Endpoints -Controller "Terrain" -Key "your_key"
```

### Direct `curl.exe` Diagnostic Recipes
```powershell
# 1. Health Probe (Uptime, timestamps, PID - always public)
curl.exe -s "https://api.digiproject.uk/information/health"

# 2. Version & Git Commit Audit (always public)
curl.exe -s "https://api.digiproject.uk/information/version"

# 3. Route & Parameter Catalog (send the key header to inspect hidden/internal endpoints)
curl.exe -s -H "key: your_key" "https://api.digiproject.uk/information/endpoints?includeignored=true"

# 4. Loaded Dynamic Assemblies & Plugins Audit (protected)
curl.exe -s -H "key: your_key" "https://api.digiproject.uk/information/assemblies"

# 5. Host Telemetry (Memory, GC Sweeps, ThreadPool - protected)
curl.exe -s -H "key: your_key" "https://api.digiproject.uk/information/system"
```

---

## 3. Access Rules & Tools

- **Tooling:** Use `curl.exe` (PowerShell/Bash) or `InvestigateServer.ps1` for API testing. Avoid `WebFetch` (GET-only).
- **Authentication:** Public GET endpoints require no auth; protected telemetry queries require the `key` request header and deny by default without it.
- **Production Guardrail:** Treat `api.digiproject.uk` as live production. Read-only GET requests are safe. **Do NOT invoke POST/PUT/DELETE write endpoints** without explicit authorization.
- **This API is the only way to measure production.** A `*.conf` resolves to a development database, not the estate, so a figure taken through one describes neither the deployed data nor a run that happened on the server — see [Coding - PostgreSQL.md](Coding%20-%20PostgreSQL.md) §6.

---

## 3. Read-Path Testing Recipe (County → Reference → Building)

Execute this safe, read-only sequence to verify client/server integration:

| Step | Target Endpoint | Description & Parameters | Return Payload |
|------|-----------------|--------------------------|----------------|
| **1** | `GET gis/administrativeareal2d/administrativeareal2Dreferencesbyadministrativearealtype?administrativearealtype=2` | Fetch counties (`2` = County). | `AdministrativeAreal2DReference[]` (extract county `Id`) |
| **2** | `GET gis/building2d/referencesbycountyid?countyid=<id>` | Fetch Cadastral Building2D references for county. | `string[]` |
| **3** | `GET gis/building/itembyreference?reference=<ref>&countyid=<id>` | Fetch 3D CityGML building by reference key and county ID. | `200` (`Building`) or `204` (No 3D match) |
| **4** | `GET gis/building/itembylatestcreatedat?countyid=<id>` | Fetch latest created 3D building in county. | `200` (`Building`) or `204` |

---

## 4. Operational Gotchas

- **A county `Id` is a polygon part, not a county.** Step 1 returns **406 records for 380 codes**: 18 counties have disconnected territory and are stored as one row per part. Enumerating counties therefore visits parts, one part's `referencesbycountyid` is not the whole county, and `idbycode` collapses a code to the lowest part. `&uniquecode=true` collapses the list to 380 but picks an arbitrary part, so it is not a way to get "the" county. Full model: [Coding - GIS Administrative Data.md](Coding%20-%20GIS%20Administrative%20Data.md).
- **A `building_2d` reference is unique only per `countyid`.** The 86 196 rows that were duplicated across sibling parts were removed on 2026-08-14, and `building2dreferencebyreference` → `CountyId` → model now resolves correctly (10/10 on each of the three affected codes). The uniqueness rule still holds — nothing added a constraint — so a future import that files a building under two parts would bring the 404 back.
- **Reference Key Matching:** `itembyreference` accepts the **Cadastral Building2D reference key** from `referencesbycountyid`. It does NOT match CityGML `UniqueId` values (stripping `ID-` prefix will fail).
- **Mandatory `countyid` Parameter:** Always pass `countyid` to `GET gis/building/itembyreference`. Omitting `countyid` triggers HTTP 500 on the live server.
- **An unknown query parameter is silently ignored, so a stale client name reads as "no filter".** Sending `itemsbypoint?…&type=County` against a build that renamed the parameter to `administrativearealtype` returned **every** administrative level covering the point (2 119 202 bytes, headed by `Polska`) instead of the county (387 089 bytes, `m. St. Warszawa`) — HTTP 200 both times. When a live response looks too large or is headed by the wrong kind of row, suspect a parameter name before suspecting the data. Full account in [Coding - WebAPI Contracts.md](Coding%20-%20WebAPI%20Contracts.md) §1.
- **An omitted parameter is not rejected.** `[ApiController]` answers 400 for a value it cannot parse (`administrativearealtype=` and `administrativearealtype=Nonsense` both 400), but an **absent** parameter keeps `default(T)` and the request succeeds. Omitting `administrativearealtype` on `administrativeareal2Dreferencesbyadministrativearealtype` returns a payload byte-identical to `administrativearealtype=0` — countries. Always pass the filter explicitly when testing.
- **A `gis/terrain/mesh3d*` 404 can just mean the radius is too small.** Counties are sampled onto a 10–100 m lattice, so a circle narrower than the lattice step encloses no stored point. At `x=638000&y=486000`: radius 50 → 404, radius 100/200/500 → 200 with elevations of 111–112 m. Widen the radius before concluding the elevation table is missing in that environment.
- **Enum Rename (`Subdivison` → `Subdivision`):** `AdministrativeArealType` member 4 was misspelled `Subdivison` and has been **renamed to `Subdivision`** — a deliberate breaking wire change, not an alias. From that build onward `Subdivison` returns **HTTP 400**; against an older deployment `Subdivision` returns **HTTP 400**. **Integer `4` is the only token that binds on every build**, so use it whenever the deployed version is unknown. Responses always carry the integer `4`.
