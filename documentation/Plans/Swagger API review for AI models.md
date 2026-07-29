# Swagger / OpenAPI review for AI-model consumption — findings & implementation plan

> Portability note: all paths below are repo-relative (each `DiGi.*` repo is a separate project).
> Source references use `RepoName/.../File.cs:line` form rather than machine-specific absolute paths.

## Purpose & scope

The deployed **Data Exchange API** (`https://api.digiproject.uk`, OpenAPI at
`/swagger/v1/swagger.json`) is intended to be consumed by AI models whose only contract is the
generated OpenAPI document. This document records a deep review of that contract for
**discoverability, correctness and machine-usability**, and defines the remaining implementation
work. All findings were verified live against the deployed API and grounded in source.

The document (`title = "Data Exchange API"`) is produced by the host **`DiGi.WebAPI.WindowsService`**
(Swashbuckle.AspNetCore 10.2.0, Microsoft.OpenApi 2.7.5), which loads the domain controllers as
runtime MVC application-part plugins from `bin/extensions/<area>/`. Configuration lives in
`DiGi.WebAPI.WindowsService/DiGi.WebAPI.WindowsService/Program.cs` (`ConfigureSwagger`, ~line 241).

**Deployment state at review (2026-07-24):** `information/version` = `0.8.8.0`; assemblies drift
(GIS `0.8.7`, GLTF `0.8.3`, Communication `0.8.1`, WebAPI/User `0.8.8`). Re-read swagger after any
deployment; versions and path counts move with releases.

---

## Status — what has already been implemented (safe fixes, session 2026-07-24)

Landed in source (build-verified, and confirmed in a locally generated swagger on host port 5010),
**pending the next deployment** to reach production:

- **Exposed selected read endpoints** via `[ApiExplorerSettings(IgnoreApi = false)]` (a conscious,
  per-endpoint decision — see the Exposure register): `gis/buildingmodel/itemsbycircle`,
  `gis/buildingmodel/itemsbyreferences`, `gis/ortodatas/estimatedcoveragefactor`,
  `gis/ortodatas/itembyreference`, `gis/ortodatas/imagebyreference`.
- **Corrected binary content types**: `gltf/gltfscene/glb` → `model/gltf-binary`;
  `gis/ortodatas/imagebyreference` → `image/jpeg` (+ `[ProducesResponseType(FileContentResult,200)]`).
- **`pageSize` schema defaults**: `[DefaultValue(250)]` on `BuildingDataByPagingParameter.PageSize`
  and `Building2DReferencesByPagingParameter.PageSize`.
- **Hardened `BuildingController.GetItemByReferenceAsync`**: wrapped the converter call in try/catch
  returning a shaped `ProblemDetails` (the root-cause `42P18` null-county crash is already fixed in
  `DiGi.GIS.PostgreSQL/.../BuildingPostgreSQLConverter.cs:132-134`; the endpoint stays hidden).

Known minor residue: the two binary endpoints still list `application/json` alongside the correct
binary media type, inherited from the base `WebAPIController [Produces("application/json")]`. Cleaned
up as part of item 5 below.

---

## Findings register

| # | Sev | Finding | Evidence |
|---|-----|---------|----------|
| **F1** | Info (by design) | Visibility is opt-out-by-default: base `WebAPIController` (`DiGi.WebAPI/.../Classes/WebAPIController.cs:9`) has `[ApiExplorerSettings(IgnoreApi=true)]`; an action appears only if it sets `IgnoreApi=false`. 14 controllers deployed, 7 documented. This is a deliberate security control (e.g. `user/*` login/secure-data, all `updateitem(s)` writes). Keep it; expose reads only by conscious choice. | `information/controllers` = 14 controllers; `gis/building/itembylatestcreatedat?countyid=5` → 200 (12.6 KB) yet absent from swagger. |
| **F2** | Critical | **Schema fidelity gap.** Swagger documents DTOs camelCase, no `_type`, enums-as-strings; the wire is DiGi `SerializableObject`: PascalCase + mandatory `_type` + integer enums. `Table.Columns` returns `ExtendedColumn` (`{_type,Name,Type,Index,Category,Description}`), not the documented `Column`. AI cannot build request bodies or parse responses for any object payload. Cause: Swashbuckle reflects public getters + `CamelCaseSchemaFilter` (`DiGi.WebAPI.WindowsService/.../Classes/CamelCaseSchemaFilter.cs`) + `JsonStringEnumConverter`, but serialization runs through the DiGi writer. | `administrativeareal2dreferencebyid?id=5` → `{"_type":"DiGi.GIS.PostgreSQL.Classes.AdministrativeAreal2DReference,DiGi.GIS.PostgreSQL","CountyId":null,"AdministrativeArealType":2,...}`. |
| **F3** | High | `AdministrativeArealType` member misspelled `Subdivison` (value 4) — `DiGi.GIS.PostgreSQL/.../Enums/AdministrativeArealType.cs:38`. It is the wire token; correct `Subdivision` is rejected. | `...referencesbyadministrativearealtype?administrativearealtype=Subdivison` → 200; `=Subdivision` → 400. |
| **F4** | High | **Opaque request/response bodies.** `gltf/gltfscene/glb` and `gltf/gltfscene/fromobjects` bind `[FromBody] JsonObject?/JsonArray?` and rehydrate via `Core.Create.SerializableObject<T>`. Swagger shows `object`+`additionalProperties:JsonNode` — no usable shape. Real shapes: `GLTFScene`, `GLTFNode[]`. **Update 2026-07-29:** the two `communication/geometricalpropagationmodel` actions originally listed here no longer exist. `/propagationresults` had already been removed when this was written (the cited line numbers never matched), and the remaining `segment3d` placeholder was deleted along with `GeometricalPropagationModelController` — it had no consumers. `DiGi.Communication.WebAPI` now ships result contract types only and exposes no endpoints. | Controller: `DiGi.GLTF.WebAPI/.../GLTFSceneController.cs:31,71`. |
| **F5** | High (fixed upstream) | `gis/building/itembyreference` without `countyid` → 500 on the deployed 0.8.7 build. `countyId` is intentionally optional (all-counties lookup); the `42P18` crash is fixed in current source (typed `NpgsqlParameter`). Controller now also try/catch-wrapped. | `?reference=ID-abc` → 500; `&countyid=5` → 204. |
| **F6** | Med | Empty/opaque response schemas. `WeatherRecord`, `GLTFScene` show zero properties (state in `private [JsonInclude]` fields + `[JsonIgnore]` getters → invisible to Swashbuckle). `histogramsummary`/`aggregatesummary/*`/`uniquevalues` return raw `JsonNode`/`{}`. | `DiGi.Weather/.../Classes/WeatherRecord.cs`; `DiGi.GLTF/.../Classes/GLTFScene.cs`. |
| **F7** | Med (fixed) | `glb` binary was declared `application/json`. Fixed to `model/gltf-binary` this session. | — |
| **F8** | Med | No `required` markers on logically-required query params; `pageSize` default was prose-only (fixed); **no next-cursor** in keyset-paged responses (bare array / `Table`) — caller must derive the cursor from the last row. | `Building2DController.cs:137-169`, `BuildingDataController.cs:318-350` (central GIS). |
| **F9** | Low | Enum serializes int on output but swagger says string; singular/plural route collisions (`...referencebycode` vs `...referencesbycode`); doc mismatches (EPW array described as "an EPW file"; `Building2D itembyid` declared `List<Building2D>` returns one); documented bare `500`s; thin `info.description` and tags lack descriptions (deferred — item 8). | swagger + live. |

---

## Implementation plan (remaining work)

### 1. Schema-fidelity engine — make swagger match the wire (addresses F2, F6) — **highest impact**

Add a Swashbuckle `ISchemaFilter` that, for types implementing
`DiGi.Core.Interfaces.ISerializableObject`, regenerates the schema from the **serialization**
contract instead of the public getters:

- Enumerate the `private readonly` fields tagged `[JsonInclude, JsonPropertyName(nameof(...))]`
  (the backing fields) and emit a property per field using the `JsonPropertyName` value (PascalCase).
- Inject a required `_type` string property whose value is
  `Core.Query.FullTypeName(type)` → `"Namespace.Type,ShortAssembly"` (see
  `DiGi.Core/.../Query/FullTypeName.cs`); mark it required and set `example`/`enum: [<value>]`.
- Render enum-typed members as integers (their underlying value), matching the wire.
- Recurse into nested `ISerializableObject` field types.

Placement options: (a) directly in `DiGi.WebAPI.WindowsService` alongside `CamelCaseSchemaFilter`;
or (b) shipped per-assembly through the existing `IWebAPISchemaFilter` plugin hook
(`DiGi.WebAPI/.../Interfaces/IWebAPISchemaFilter.cs`) so each domain assembly documents its own
types. Prefer (a) for a single, uniform implementation. **Reconcile `CamelCaseSchemaFilter`:** it
force-camelCases every schema and is the direct cause of F2 — the new filter must run after it and
overwrite, or `CamelCaseSchemaFilter` must be scoped to non-`ISerializableObject` types.
Fixes `WeatherRecord`/`GLTFScene`/`ControllerInformation`/all references/`Table`/`ExtendedColumn` at
once. Document that `Table.Columns` runtime element type is `ExtendedColumn`.

### 2. Typed schemas + examples for the opaque endpoints (F4/F6)

For the `JsonObject`/`JsonArray`-bound actions, attach real request/response schemas and examples so
AI can build bodies. Once the item-1 engine exists, register the concrete types with Swashbuckle
(via `[ProducesResponseType]`/`[Consumes]` typed overloads or an operation filter mapping the
action to the DiGi type) so the engine emits their shapes:

- Requests: `GLTFScene`; `GLTFNode[]`.
- Responses: `GLTFScene`. Typed `HistogramBucket` and aggregate-result schemas to replace raw
  `JsonNode` on `histogramsummary`/`aggregatesummary/*`.

**Update 2026-07-29:** the `communication/*` items dropped from this list with F4 above — there are no
communication endpoints left to document. When the propagation calculation is exposed over HTTP from
`DiGi.Communication.WebAPI`, the request shape will be `GeometricalPropagationModel`
(`CommunicationRelationCluster.Values[]` of `Antenna`, `ScatteringObject`,
`SimpleMultipathPowerDelayProfile`) with the ready-made body fixture
`DiGi.Test/files/GeometricalPropagationModel.json`, and the response will be the existing
`DiGi.Communication.WebAPI.Classes.GeometricalPropagationResult` contract.

### 3. Rename `Subdivison` → `Subdivision` (F3) — **breaking wire change**

Migration (do not flip in one step):
1. Add `Subdivision = 4` as the canonical member and keep `Subdivison` as an alias (e.g. a second
   member with the same value is not allowed for name-based `JsonStringEnumConverter`; instead accept
   both tokens at the binding boundary — a custom converter or query-string normalization mapping the
   old token to the new).
2. Announce in the changelog / notify known clients; emit the new token in responses.
3. After a deprecation window, remove old-token acceptance.
Call sites to update: `DiGi.GIS.PostgreSQL/.../Enums/AdministrativeArealType.cs:38`,
`DiGi.GIS.PostgreSQL/.../Query/AdministrativeArealType.cs:21,44,45`, both
`AdministrativeAreal2DController` copies (central `DiGi.GIS.WebAPI` and UI host).

### 4. Standardize error contracts (F9)

Consistent `400`/`404`/`422` + `ProblemDetails`; never document a bare `500` (it signals an
unhandled path). Audit each opted-in action's `[ProducesResponseType]` set for symmetry
(e.g. `administrativeareal2dreferencepathsbynameparameter` currently documents a bare `500`).

### 5. Binary media-type cleanup (F7 residue)

Suppress the inherited `application/json` on binary responses (`glb`, `imagebyreference`) so only the
binary media type is advertised — e.g. override `[Produces]` at the action so Swashbuckle does not
merge the base controller's JSON producer, or add an operation filter that strips `application/json`
from `FileContentResult` responses.

### 6. Pagination envelope (F8)

Return `nextCursor`/`hasMore` (or an explicit documented derivation contract) from
`building2dreferencesbypagingparameter` and `tablebybuildingdatabypagingparameter` so clients don't
have to infer the cursor from the last row. If wrapping the payload, keep it additive/versioned.

### 7. New endpoints (naming aligned to existing routes)

- **`GET /information/schema?type=<FullTypeName>`** and **`GET /information/schemas`** — return the
  JSON schema (property names, types, `_type` value, enum encodings) for any DiGi serializable type,
  built from the existing `SerializationManager`. The single biggest AI enabler: lets a client fetch
  the exact shape for a `_type` at runtime. Aligns with `information/controllers` / `information/version`.
- **`POST /gltf/gltfscene/glbfromobjects`** — geometry → binary `.glb` in one call (composes
  `gltf/gltfscene/fromobjects` + `gltf/gltfscene/glb`), returning `model/gltf-binary`.
- **`GET /information/health`** — liveness/readiness.
- (Batch `itemsbyreferences` already exists on `gis/building` and `gis/buildingmodel` — hidden, not
  new; see Exposure register.)

### 8. API self-description — `info.description` conventions + per-tag descriptions (F9) — *separate issue*

An AI's only orientation comes from the document-level `info.description` (the API-wide conventions —
especially the `_type`/PascalCase/integer-enum contract from F2) and the per-controller `tags[].description`.
Both are still wanted, but must be implemented as **per-assembly plugin filters**, not a host-side
hardcoded constant/map:

- Each domain WebAPI assembly (`DiGi.GIS.WebAPI`, `DiGi.Communication.WebAPI`, `DiGi.GLTF.WebAPI`,
  `DiGi.WebAPI`) contributes its own tag descriptions — and its slice of the conventions text — through
  the existing `IWebAPIDocumentFilter` hook (`DiGi.WebAPI/.../Interfaces/IWebAPIDocumentFilter.cs`).
  The host already discovers and registers plugin filters at load time
  (`DiGi.WebAPI.WindowsService/.../Program.cs` `LoadExtensionsAsync` → `types_DocumentFilters` /
  `types_SchemaFilters`), so no host code change is needed to pick them up.
- Rationale: **ownership/locality** — descriptions live next to the controllers that define the tags,
  so they cannot drift; the host must not hardcode prose for plugin controllers it does not own.
- A first pass hardcoded these in the host (`Constans/Swagger.cs` + a `TagDescriptionsDocumentFilter`
  registered via `options.DocumentFilter<>()`); that approach was **reverted** for the reason above.
  The conventions text drafted there is a usable starting point for the per-assembly implementation.

---

## Exposure register (invisible endpoints — conscious-decision reference)

Keep opt-out-by-default (F1). Record of every currently-hidden action and the recommendation.

| Endpoint | Verb | Kind | Recommendation |
|----------|------|------|----------------|
| `gis/buildingmodel/itemsbycircle` | GET | read (3D models) | **Exposed** (session 2026-07-24) |
| `gis/buildingmodel/itemsbyreferences` | GET | read (3D models) | **Exposed** |
| `gis/ortodatas/itembyreference` | GET | read (ortho) | **Exposed** |
| `gis/ortodatas/estimatedcoveragefactor` | GET | read (ortho) | **Exposed** |
| `gis/ortodatas/imagebyreference` | GET | read (ortho image) | **Exposed** |
| `gis/building/itembyreference` | GET | read (CityGML) | Candidate — declined this round |
| `gis/building/itemsbyreference` | GET | read (CityGML) | Candidate — declined |
| `gis/building/itemsbyreferences` | POST | read (CityGML batch) | Candidate — declined |
| `gis/building/itembylatestcreatedat` | GET | read (CityGML) | Candidate — declined |
| `gis/yearbuiltdata/itemsbyreference` | GET | read (attribute) | Candidate — declined |
| `gis/occupancydata/{administrativeareal2d,building2d}/itemsbyreference` | GET | read (attribute) | Candidate — declined |
| `gis/heattransfercoefficient/regulatedheattransfercoefficientsbyyear` | GET | read (regulatory) | Candidate — declined |
| `gis/ortodatas/estimatedcoveragefactors` | POST | read (batch) | Optional |
| `gis/ortodatas/containsbyreferences` | POST | read/queue | Keep hidden (processing) |
| `gis/ortodatas/nextbuilding2dreferences` | POST | queue | Keep hidden (processing) |
| `.../updateitem`, `.../updateitems`, `gis/ortodatas/updateitemsby*`, `gis/occupancydata/*/updateitems` | POST | **write** | Keep hidden (mutating) |
| `user/user/login`, `user/user/secure-data` | POST/GET | **auth** | Keep hidden (security) |
| `gis/administrativeareal2d/itemsby*`, `gis/building2d/itemsby*`/`itembyid`/`count`, etc. | GET/POST | read | Expose case-by-case if AI use cases arise |

---

## Rollout, risk & verification

- **Ordering:** item 1 (schema engine) unblocks items 2 & 7; do it first. Item 3 (breaking enum
  rename) needs the deprecation window and should ship on its own release with a changelog entry.
- **Per-repo touch list:** schema engine + tag/description + media-type/operation filters →
  `DiGi.WebAPI.WindowsService` (and/or per-assembly `IWebAPISchemaFilter`); enum + call sites →
  `DiGi.GIS.PostgreSQL` + `DiGi.GIS.WebAPI` (+ UI host); typed schemas → the owning WebAPI assemblies;
  new endpoints → `DiGi.WebAPI` (`information/*`), `DiGi.GLTF.WebAPI` (`glbfromobjects`).
- **Deployment:** the exe loads plugins from `bin/extensions/<area>/`; a redeploy copies fresh
  assembly DLLs there. Nothing reaches production until the affected assemblies are redeployed
  (assembly versions drift independently).
- **Local regression check (used this session):** build the projects (zero warnings —
  `TreatWarningsAsErrors` on template-derived projects), stage the rebuilt extension DLLs into
  `bin/extensions/<area>/`, run `DiGi.WebAPI.WindowsService.exe` with
  `ASPNETCORE_ENVIRONMENT=Development` (binds Kestrel port **5010** from `appsettings.json`), then
  `GET http://127.0.0.1:5010/swagger/v1/swagger.json` and diff against the deployed document. Re-run
  the live probes (enum binding int/name; `itembyreference` shaped error; newly-visible paths).
- **Testing rule:** these are manual, on-demand checks against live/local hosts — **never** add them
  to `DiGi.Test` or any automated suite (per `AI Guidelines/Coding - Deployed WebAPI.md`).
