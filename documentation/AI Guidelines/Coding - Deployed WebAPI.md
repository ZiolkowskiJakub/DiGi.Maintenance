# Coding — Deployed WebAPI (Live Endpoint Testing)

Directives for manual, on-demand testing against live production endpoints (`https://api.digiproject.uk`). **Do NOT add these tests to `DiGi.Test` or automated test suites.** Which machine runs which part of the estate — and why that decides where to measure and where to look for a log — is §5.

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

- **Query the host sequentially. Concurrency exhausts the Npgsql pool and the failure looks like a broken endpoint.** Parallel requests return **HTTP 500** from endpoints that are perfectly healthy: `gis/yearbuiltdata/itemsbyreferences` answered 500 (`"Database read failed."`) under 12 parallel workers and returned 200 in 0.07 s the moment it was retried alone. An audit that fans out therefore reports defects that do not exist, and — worse — can read a genuine defect as noise. **Re-test every 500 in isolation before believing it**, and keep a sweep to a handful of workers at most. Second occurrence: `gis/terrain/coveragebycountyid` did the same, and there only a service restart cleared it.
- **A 500 on a read of a large partition is usually a *timeout*, and cache warmth decides it — not row count.** `gis/building2d/referencesbycountyid` hardcodes `commandTimeout: 30` with no `commandtimeout` parameter (`Building2DController.cs:876`, `DiGi.GIS.WebAPI#27`), so a **cold** partition exceeds it: county 204 (30 583 refs) answered **500 after 55.6 s**, then **200 in 0.13 s** on the retry, while county 5 (33 687 refs — larger) answered 200 in 0.13 s warm throughout. Retry before concluding anything; if a sweep needs the endpoint, warm each partition first. Note this is **step 2 of the §3 recipe above**, so the recipe itself hits it on any county not queried recently.
- **Prefer `estimated=true` for row counts when sweeping.** On `countbycountyid`, the exact count took ~33 s per county against ~0.05 s estimated, and the estimate matched the exact figure to the row on every county checked. A 406-county exact sweep is ~37 minutes of load on production for a number the estimate already gives.
- **A county `Id` is a polygon part, not a county.** Step 1 returns **406 records for 380 codes**: 18 counties have disconnected territory and are stored as one row per part. Enumerating counties therefore visits parts, one part's `referencesbycountyid` is not the whole county, and `idbycode` collapses a code to the lowest part. `&uniquecode=true` collapses the list to 380 but picks an arbitrary part, so it is not a way to get "the" county. Full model: [Coding - GIS Administrative Data.md](Coding%20-%20GIS%20Administrative%20Data.md).
- **A `building_2d` reference is unique only per `countyid`.** The 86 196 rows that were duplicated across sibling parts were removed on 2026-08-14, and `building2dreferencebyreference` → `CountyId` → model now resolves correctly (10/10 on each of the three affected codes). The uniqueness rule still holds — nothing added a constraint — so a future import that files a building under two parts would bring the 404 back.
- **Reference Key Matching:** `itembyreference` accepts the **Cadastral Building2D reference key** from `referencesbycountyid`. It does NOT match CityGML `UniqueId` values (stripping `ID-` prefix will fail).
- **Mandatory `countyid` Parameter:** Always pass `countyid` to `GET gis/building/itembyreference`. Omitting `countyid` triggers HTTP 500 on the live server.
- **An unknown query parameter is silently ignored, so a stale client name reads as "no filter".** Sending `itemsbypoint?…&type=County` against a build that renamed the parameter to `administrativearealtype` returned **every** administrative level covering the point (2 119 202 bytes, headed by `Polska`) instead of the county (387 089 bytes, `m. St. Warszawa`) — HTTP 200 both times. When a live response looks too large or is headed by the wrong kind of row, suspect a parameter name before suspecting the data. Full account in [Coding - WebAPI Contracts.md](Coding%20-%20WebAPI%20Contracts.md) §1.
- **An omitted parameter is not rejected.** `[ApiController]` answers 400 for a value it cannot parse (`administrativearealtype=` and `administrativearealtype=Nonsense` both 400), but an **absent** parameter keeps `default(T)` and the request succeeds. Omitting `administrativearealtype` on `administrativeareal2Dreferencesbyadministrativearealtype` returns a payload byte-identical to `administrativearealtype=0` — countries. Always pass the filter explicitly when testing.
- **A `gis/terrain/mesh3d*` 404 can just mean the radius is too small.** Counties are sampled onto a 10–100 m lattice, so a circle narrower than the lattice step encloses no stored point. At `x=638000&y=486000`: radius 50 → 404, radius 100/200/500 → 200 with elevations of 111–112 m. Widen the radius before concluding the elevation table is missing in that environment.
- **Enum Rename (`Subdivison` → `Subdivision`):** `AdministrativeArealType` member 4 was misspelled `Subdivison` and has been **renamed to `Subdivision`** — a deliberate breaking wire change, not an alias. From that build onward `Subdivison` returns **HTTP 400**; against an older deployment `Subdivision` returns **HTTP 400**. **Integer `4` is the only token that binds on every build**, so use it whenever the deployed version is unknown. Responses always carry the integer `4`.


---

## 5. Deployment Topology — Which Machine Runs What

The estate is split across machines with different roles. Know which one runs the code before measuring,
reading a log or blaming a component.

| Role | Runs | Reached through |
|---|---|---|
| **Database server** (the stronger machine) | the production PostgreSQL databases; `DiGi.WebAPI.WindowsService` hosting the GIS Web API and its `extensions\*` | `https://api.digiproject.uk` |
| **Web server** | `DiGi.GIS.WebAPI.UI` under IIS | `https://gis.digiproject.uk` |
| **Development / test machines** | editing, builds, `DiGi.Test`, development databases behind `*.conf` | — (never production; [Coding - PostgreSQL.md](Coding%20-%20PostgreSQL.md) §6) |

`DiGi.GIS.PostgreSQL.UI` (the tray application) is installed on **both** servers, and each background task
runs on whichever server it was started on.

Hardware details — CPU, cores, memory, OS build — are deliberately not recorded here: they change with the
estate. Read them on the machine at the time you measure, and cite the measurement (issue comment, date)
rather than the machine's specification.

### Rules that follow

- **Measure a limit on the machine that will run the code, and say which role you measured.** The two
  servers differ in capacity, so a figure taken on one does not transfer to the other. A synchronous limit
  of a `DiGi.GIS.WebAPI.UI` endpoint is measured on the **web server**; an API's on the **database
  server**; a development machine's figure is a relative comparison only. Worked example: the CPU
  shading-solver probe of `DiGi.Solar#7` ran on the database server while believed to be on the web
  server, and its limits (100 receivers, "about 16 s for a mid-rise block") were four to ten times too
  generous for the web server that actually runs the solve — the same request took 51–159 s there, and
  `DiGi.GIS.WebAPI.UI#59` cut the limit to 30. Relative findings (a tolerance halving the solve time, one
  solve at a time beating two) did transfer; absolute times did not.
- **A log lives on the machine that ran the code.** The GIS Web API writes its Serilog file on the
  database server. `DiGi.GIS.WebAPI.UI` writes `logs\log-yyyyMMdd.txt` beside its own application on the
  web server — IIS discards console output, so without that file its `ILogger` lines go nowhere. A tray
  task's log is on the server that ran the task. None of them is on a development machine: searching an
  editing machine for a production run's log finds nothing and proves nothing.
- **A slow page is not necessarily a slow API.** A request to the web server usually fans out to the
  database server. Compare the two logs before choosing a culprit: in `DiGi.GIS.WebAPI.UI#59` the API log
  showed every upstream call answering in milliseconds, which placed the minutes of latency in the web
  server's own computation.
- **Heavy computation competes with serving pages.** Work that runs inside `DiGi.GIS.WebAPI.UI` shares
  the web server with every page it serves; gate it (one solve at a time, a size ceiling that answers
  413) and size those gates from web-server measurements.
