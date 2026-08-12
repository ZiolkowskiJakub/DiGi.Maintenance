# Coding — Deployed WebAPI (Live Endpoint Testing)

Directives for manual, on-demand testing against live production endpoints (`https://api.digiproject.uk`). **Do NOT add these tests to `DiGi.Test` or automated test suites.**

---

## 1. Endpoints & Swagger Caveats

- **Base URL:** `https://api.digiproject.uk` (root `/` returns HTTP 404).
- **Swagger JSON:** `https://api.digiproject.uk/swagger/v1/swagger.json`.
- **Deployed Controllers:** `GET /information/controllers` (returns real deployed controller list and assembly versions).

### Swagger Contract Limitations
1. **Incomplete Endpoint List:** Base `WebAPIController` sets `[ApiExplorerSettings(IgnoreApi = true)]`. Write endpoints (`updateitem(s)`), `user/*`, and several `item*` reads are omitted from Swagger. Query `GET /information/controllers` to discover all endpoints.
2. **Schema Inaccuracies:** Wire format uses **PascalCase property names**, a mandatory `_type` discriminator (`"Namespace.Type,ShortAssembly"`), and **integer enums**. Ignore Swagger schema camelCase/string-enum definitions.

---

## 2. Access Rules & Tools

- **Tooling:** Use `curl` (Bash) for API testing. Avoid `WebFetch` (GET-only).
- **Authentication:** GET endpoints require no auth.
- **Production Guardrail:** Treat `api.digiproject.uk` as live production. Read-only GET requests are safe. **Do NOT invoke POST/PUT/DELETE write endpoints** without explicit authorization.

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
- **A `building_2d` reference is unique only per `countyid`.** ~86k rows are duplicated across sibling parts, so `building2dreferencebyreference` answers with one part's row and feeding that `CountyId` straight into a model lookup can return 404 for a building that exists under the sibling.
- **Reference Key Matching:** `itembyreference` accepts the **Cadastral Building2D reference key** from `referencesbycountyid`. It does NOT match CityGML `UniqueId` values (stripping `ID-` prefix will fail).
- **Mandatory `countyid` Parameter:** Always pass `countyid` to `GET gis/building/itembyreference`. Omitting `countyid` triggers HTTP 500 on the live server.
- **Enum Misspelling (`Subdivison`):** `AdministrativeArealType` member 4 is misspelled on the wire as **`Subdivison`** (missing second `i`). Sending correct spelling `Subdivision` returns **HTTP 400**. Pass integer `4` or exact string `Subdivison`.
