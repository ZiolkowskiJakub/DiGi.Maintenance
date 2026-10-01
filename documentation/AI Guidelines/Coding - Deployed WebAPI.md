# Coding — Deployed WebAPI (Live Endpoint Testing)

Directives for manual, on-demand testing against live production endpoints (`https://api.digiproject.uk`). **Do NOT add these tests to `DiGi.Test` or automated test suites.** Which machine runs which part of the estate — and why that decides where to measure and where to look for a log — is §5.

---

## 1. Endpoints & Swagger Caveats

- **Base URL:** `https://api.digiproject.uk` (root `/` returns HTTP 404).
- **Swagger JSON:** one document per route prefix, plus the full document — see *Swagger Documents* below.
- **Diagnostic Suite (`InformationController`):**
  - `GET /information/health` — liveness/readiness probe (`Status`, `ServerTimeUtc`, `Uptime`, `ProcessId`).
  - `GET /information/version` — multi-tier version audit (Host & `DiGi.WebAPI` versions, git commits, CLR runtime).
  - `GET /information/controllers` — deployed controller list, assembly metadata, and route prefixes.
  - `GET /information/endpoints` — full catalog of registered routes, HTTP verbs, and parameter contracts. Pass `?includeignored=true` to inspect write/internal endpoints hidden from Swagger.
  - `GET /information/assemblies` — inventory of loaded assemblies in `AssemblyLoadContext` (verifying dynamic `extensions/` plugins).
  - `GET /information/system` — safe process telemetry (working set memory, GC heap, thread pool threads, OS version).

### Swagger Documents — Fetch the Smallest One That Answers the Question

`DiGi.WebAPI.WindowsService` publishes one OpenAPI document per **first route segment**, discovered at
start-up from the loaded controllers, plus one document holding everything:

| URL | Contents | Size (2026-10-01) |
|---|---|---|
| `/swagger/gis/swagger.json` | `DiGi.GIS.WebAPI` — 95 paths, 83 schemas | ~407 KB |
| `/swagger/information/swagger.json` | `DiGi.WebAPI` diagnostics — 6 paths, 9 schemas | ~27 KB |
| `/swagger/user/swagger.json` | `DiGi.User.WebAPI` — 5 paths, 3 schemas | ~10 KB |
| `/swagger/gltf/swagger.json` | `DiGi.GLTF.WebAPI` — 2 paths, 12 schemas | ~18 KB |
| `/swagger/swagger.json` (same as `/swagger/full/swagger.json`) | every endpoint of every prefix — 108 paths, 99 schemas | ~454 KB |

**To keep the context small, never load the full document when you work on one prefix, and never load
`gis` whole when you need one endpoint:**

1. **Route or parameter names only?** Skip Swagger: `InvestigateServer.ps1 -Endpoints -Controller "<Name>"` (§2)
   returns just that controller's routes and parameters.
2. **Prefix `user`, `gltf` or `information`?** Read that prefix document whole; it is a few KB and
   self-contained (every `$ref` resolves inside it).
3. **Prefix `gis`?** Pull out the operation and the schemas it references, not the file:
   ```powershell
   $doc = Invoke-RestMethod "https://api.digiproject.uk/swagger/gis/swagger.json"
   $doc.paths.PSObject.Properties.Name -like "*/terrain/*"                  # list the routes (keys are lower case)
   $doc.paths."/gis/terrain/mesh3dbycircle" | ConvertTo-Json -Depth 20     # one operation
   $doc.components.schemas.Mesh3D | ConvertTo-Json -Depth 20               # the schema its 200 response references
   ```
   `Invoke-RestMethod` decodes the body as UTF-8 JSON; piping `curl.exe` into `ConvertFrom-Json` goes
   through PowerShell's code-page decoding (the trap in `GitHub - Issues.md` §1).
4. **Use `/swagger/swagger.json` only when you need several prefixes at once.**

Rules the host applies:

- The document name is the first route segment, lower case (`gis/[controller]` → `gis`,
  `[controller]` on `UserController` → `user`). A new extension with a new prefix gets its own document
  with no host change. A prefix may not be named `full` or `swagger`.
- **A 404 on a prefix document means the prefix has no Swagger-visible endpoint, not that the extension is
  missing.** An extension whose controllers are all `IgnoreApi` (see Limitations 1 below) produces no document — `communication`
  today. Use `GET /information/endpoints?includeignored=true` for those.
- `info.version` of a prefix document is the version of the extension assembly that serves it
  (`gis` 0.8.9 while the host is 0.8.8). The full document carries the host version.
- `/swagger/v1/swagger.json` was removed by `DiGi.WebAPI.WindowsService#2`. If `/swagger/swagger.json`
  answers 404, the deployed host predates that change: use `/swagger/v1/swagger.json`, which then holds
  everything (see *The Deployed Build Lags the Repository* below).

### Swagger Contract Limitations
1. **Incomplete Endpoint List:** Base `WebAPIController` sets `[ApiExplorerSettings(IgnoreApi = true)]`, so an action appears in Swagger only when it or its controller opts back in with `IgnoreApi = false`. All of `user/*` and `information/*` do; write endpoints (`updateitem(s)`) and several `item*` reads do not. Query `GET /information/endpoints?includeignored=true` or `GET /information/controllers` to discover all active endpoints.
2. **Payload Schemas Follow the Writer:** since `DiGi.WebAPI.WindowsService#3` (deployed 2026-10-01) the host's `WireFormatSchemaFilter` documents each payload in the format actually written, and since `#6` that includes enums. Production GET payloads of every sampled prefix validate strictly against the served documents, enum properties included.
   - **DiGi `ISerializableObject` payloads** (written by the DiGi serializer): exact member names (**PascalCase** by convention — a member without `[JsonPropertyName]` keeps its field name, e.g. `Building.roofTypeId`), a mandatory `_type` discriminator (`"Namespace.Type,ShortAssembly"`, required, with the type's own name as `example`), and every member `required` because the serializer writes all of them, `null` explicitly. Always a JSON object, also for a DiGi type that is an `IEnumerable` (`EPWFile`).
   - **Open DiGi schemas** — an interface, an abstract type, a type writing its own JSON (`ToJsonObject` override) — declare only `_type` and allow additional properties: the payload carries the members of the concrete type `_type` names. A concrete type that other loaded types derive from (`WeatherRecord`, holding `DataRecord`s) lists its members but allows additional ones too.
   - **MVC payloads** (`Ok(...)` POCOs such as `UpdateItemsResult`, `ProblemDetails`) are camelCase with **string** enums — that is what the MVC formatter writes.
   - **Enums inside DiGi payloads travel as integers and are declared inline as integers** (`DiGi.WebAPI.WindowsService#6`): `"AdministrativeArealType": 2` is documented as `type: integer`, with the values in numeric order (`[-1, 0, 1, 2, 3, 4]`), the member names in the same order in `x-enum-varnames` / `x-enumNames`, and `Wire values (integer): Undefined = -1, ...` at the end of the description. A nullable enum lists `null` last among its values, because OpenAPI 3.0's `nullable` widens `type` only. A `[Flags]` enum lists no values and describes its bits instead.
   - **Enum components are the member-name strings that query parameters and MVC payloads use.** A query parameter `$ref`s its string component, and its description carries the integer values and the advice to send the integer (`Coding - WebAPI Contracts.md`). Parameters are camelCase and bind the name or the integer alike. An enum component nothing references any more (one used only by DiGi payloads) is removed from the document.
   - **DiGi request bodies are read by MVC, not by the DiGi serializer.** A `[FromBody]` DiGi parameter (`HistogramRequestParameter`, ...) is documented in the DiGi wire format, which MVC accepts (names case-insensitive, `_type` ignored, enums as integers or names). A plain object nested in one (`FilterGroup`, `FilterCondition`) keeps its camelCase schema with string enums.

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
