# Coding — Deployed WebAPI (live endpoint testing)

How to exercise the deployed DiGi WebAPI to verify client/server changes end-to-end against real
data. These are **manual, on-demand checks** run from the terminal — they are **not** xUnit tests and
must **never** be added to `DiGi.Test` or any automated suite (they depend on live production data
that changes). For automated tests see [Coding - Automatic Tests.md](Coding%20-%20Automatic%20Tests.md).

## Endpoint

- **Base URL:** `https://api.digiproject.uk` (root `/` returns 404).
- **OpenAPI/Swagger (source of truth for routes, verbs, schemas):** `https://api.digiproject.uk/swagger/v1/swagger.json`.
- **Deployed controllers + assembly versions:** `GET /information/controllers`.
- Always confirm the exact route/verb/parameters from swagger before scripting a call — the lists
  below are a convenience snapshot and the deployment may be a different assembly version than local
  source.

## Access rules

- **No authentication** is currently required for GET endpoints (Kestrel / ASP.NET Core).
- Use the **`curl`** (Bash) tool for testing — it supports any verb, headers and shows real status
  codes. `WebFetch` is GET-only and refuses authenticated URLs, so it is only good for a quick read.
- **Treat `api.digiproject.uk` as production.** Read-only GETs are safe. Do **not** call write/POST
  endpoints (`updateitem(s)`, BuildingModel uploads, etc.) without an explicit, scoped go-ahead and,
  ideally, a non-production target.
- POST bodies are **DiGi typed JSON** — a `_type` discriminator plus the exact
  `Core.Convert.ToSystem_String(...)` shape, not plain JSON. Prefer the GET endpoints below for
  discovery so you rarely need to hand-build a typed body.

## Route shape

Controllers route on `gis/[controller]` lowercased — `gis/building`, `gis/building2d`,
`gis/administrativeareal2d`, `gis/buildingmodel`, `gis/buildingdata`, …

## Read-path test recipe (county → reference → building)

Chains only GET endpoints, so it is safe to run at any time:

1. **Counties** — `GET gis/administrativeareal2d/administrativeareal2Dreferencesbyadministrativearealtype?administrativearealtype=2`
   (`2` = County; enum `DiGi.GIS.PostgreSQL.Enums.AdministrativeArealType`: Country 0, Voivodeship 1,
   County 2, Municipality 3, Subdivision 4). Returns `AdministrativeAreal2DReference[]`; the `Id`
   field is the county id used by the building endpoints.
2. **Building2D reference keys for a county** — `GET gis/building2d/referencesbycountyid?countyid=<id>`
   → `string[]`.
3. **Single CityGML building by reference** — `GET gis/building/itembyreference?reference=<ref>&countyid=<id>`
   → `200` with a `Building`, or `204` when no CityGML building matches that Building2D.
4. **Latest building (no reference needed)** — `GET gis/building/itembylatestcreatedat?countyid=<id>`
   → `200` `Building` or `204`.

Worked example (verified 2026-07-24): county `Id 5` (code `0201`, *bolesławiecki*) → of the first ten
`referencesbycountyid` keys, **one returned 200 (~30 KB Building), nine returned 204** — i.e. only a
fraction of 2D buildings have a stored 3D building, which is exactly why
`UIBuildingModelsFromDatabasePostTask` footprint-extrudes the 204 cases.

## Gotchas

- The `itembyreference` key is the **Building2D reference** (the cadastral key from
  `referencesbycountyid`), **not** the CityGML `UniqueId`. Deriving a reference by stripping the
  `ID-` prefix off a `UniqueId` does **not** match.
- `GET gis/building/itembyreference` **without** `countyid` currently returns **HTTP 500** (unhandled
  server exception). Always pass `countyid`. (Endpoint-hardening tracked separately;
  `BuildingController.GetItemByReferenceAsync` should degrade to 400/204 for a missing county.)
- Swagger `paths` count and assembly versions drift with deployments — re-read swagger rather than
  trusting a cached route list.
