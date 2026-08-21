---
name: coding-gis-administrative-data
description: Use when touching administrative_areal_2d, building_2d, or anything keyed by a county code or id - why a county code is not a key (BDOT10k stores one row per polygon part, so 406 county rows cover 380 codes), why those rows must never be deduplicated, the key-resolution matrix and the mandatory ORDER BY on any LIMIT/FirstOrDefault, plus the AdministrativeArealType wire gotchas.
---

# AI Guidelines: GIS Administrative Data (`administrative_areal_2d` & county keying)

## Mandatory Rule

> **A county code does NOT identify one county row. Key every write and every lookup by the county `id`, never by `code`.**

18 of Poland's 380 counties have disconnected territory and are stored as **several rows sharing one
code**. Resolving a code to "the" county picks one of them, and everything filed under the losing row
reads back `404` / `204` with no error anywhere. Full evidence:
[DiGi.GIS.PostgreSQL#1](https://github.com/ZiolkowskiJakub/DiGi.GIS.PostgreSQL/issues/1).

---

## 1. How the data is stored

### Source

Geoportal BDOT10k, `Polska_GML.zip`, three levels of nesting:

```
Polska_GML.zip
└── BDOT10k/<voivodeship>_GML.zip      16 files (02, 04, …, 32)
    └── <countyCode>_GML.zip           380 total, one per county, codes unique
        └── PL.PZGiK.<n>.<code>/BDOT10k/…__OT_ADJA_A.xml   administrative units
                                       …__OT_ADMS_A.xml   settlements
                                       …__OT_BUBD_A.xml   building footprints
```

**Entry naming is inconsistent** — voivodeship `24` holds bare `2401_GML.zip`, every other voivodeship
holds `26/2601_GML.zip`. Match on the basename, never the full path.

`OT_ADJA_A.xml` is the administrative-division layer (`rodzaj` = `państwo` / `województwo` / `powiat` /
`gmina`). `OT_ADMS_A.xml` is settlements — **not** the hierarchy, despite the similar name.

### The multi-part rule

**BDOT10k stores one `OT_ADJA_A` feature per polygon part.** A county whose territory is disconnected
appears as several `powiat` features in its own package, and the importer creates one
`administrative_areal_2d` row per feature.

> **Row count for a code == `powiat` feature count in that code's source package.** Verified 25/25
> (all 18 multi-part codes plus 7 single-row controls). There is no re-import artifact anywhere in
> this table — the source has 380 packages, 380 distinct codes, zero duplicates.

### Resulting table shape

| Level | Rows | Distinct codes | Codes with >1 row |
|---|---|---|---|
| Country (`type_id` 0) | 406 | **1** (`10`, "Polska"/"POLSKA") | 1 |
| Voivodeship (1) | 406 | 16 | 16 |
| County (2) | 406 | 380 | 18 |
| Municipality (3) | 2 555 | 2 477 | 64 |

**Every part carries its own private ancestor chain.** Each country row has exactly one voivodeship;
each voivodeship exactly one county. Hence 406 country rows for a single country. `country_id` /
`voivodeship_id` on a county row point into that county's *own* chain — they are not shared, and two
rows of the same county have different parents. `county_id` is **null** on every county row.

### The parts are real area — never "deduplicate" them

| Code | County | Parts | Main (ha) | Other parts (ha) |
|---|---|---|---|---|
| 2412 | rybnicki | 3 | 11 441 | **8 477, 2 412** |
| 0418 | włocławski | 3 | 139 379 | **7 068**, 505 |
| 1206 | krakowski | 2 | 116 625 | **6 271** |
| 2401 | będziński | 2 | 32 718 | **3 662** |
| 2212 | słupski | 2 | 235 118 | 0.05 |

26 non-main parts, median 11.6 ha, max 8 477 ha, 8 above 100 ha. For `2412` the largest polygon is
only 52 % of the county. **Deleting sibling rows discards up to 43 % of a county's territory.**
The multi-part codes are `0418 0620 0662 1016 1019 1206 1423 2212 2262 2401 2402 2404 2405 2410 2412
2479 2612 3020`.

---

## 2. Key-resolution matrix — every consumer picks a different part

| Consumer | Selection | Picks for `2212` |
|---|---|---|
| WebAPI `updateitems…?code=` (writes) | `GetIdsByCodeAsync` → **every part**, split per item | 73482 *and* 73485 |
| `GetIdByCodeAsync` (reads, `idbycode`) | `ORDER BY id ASC` + `LIMIT 1` → lowest | 73482 |
| `…referencesbyadministrativearealtype&uniquecode=true` | `DISTINCT ON (code) … ORDER BY code, id ASC` → lowest | 73482 |
| `GetBuilding2DReferenceByReferenceAsync` | `ORDER BY id ASC` → lowest | 73482 |
| Subdivision import | by geometry — genuinely split across parts | 1 / 356 |

The write path stopped collapsing the code: the five `updateitems…?code=` actions pass every part to
their `updateitemsbycountyids` counterpart, which files each item under the part it belongs to. The
remaining `GetIdByCodeAsync` callers are the read endpoint `idbycode` and `DiGi.GIS.UI`'s
`MainWindow.xaml.cs` (three sites) — the desktop application still picks the lowest part.

`ORDER BY` on the first three was added as part of the issue #1 fix. **Before it, `LIMIT 1` with no
ordering returned 73485** — heap order differs from id order in this table today, so the pick was
arbitrary in fact, not just in theory, and it demonstrably changed between import runs.

> **Any `LIMIT`/`FirstOrDefault` over `administrative_areal_2d` or `building_2d` needs an explicit
> `ORDER BY`.** Without one PostgreSQL guarantees nothing, and the row silently changes with the
> query plan, a vacuum, or heap ordering.

---

## 3. `building_2d` duplication across sibling parts — repaired 2026-08-14

Three codes held the same building reference under two parts at once — **86 196 duplicate rows**,
produced by repeated imports resolving one code to different parts back when that resolution had no
`ORDER BY`. **They were removed on 2026-08-14** by `PostgreSQLBuilding2DCountyPartRepairTask`, which
re-filed each building under the part its footprint lies in and deleted the copies left behind:

```
             before                          after
2212  73482 (10 198)  73485 (44 809)   ->   73482 (1)      73485 (44 809)
2405  76989 (24 260)  76984 (42 588)   ->   76989 (3)      76984 (42 585)
2612  86713 (51 740)  86698 (51 739)   ->   86713 (1)      86698 (51 739)
```

The union per code is unchanged — 44 810 / 42 588 / 51 740 — so no building lost its last row. Full
account in [DiGi.GIS.PostgreSQL#1](https://github.com/ZiolkowskiJakub/DiGi.GIS.PostgreSQL/issues/1).

Still true, and still worth knowing:
- A `reference` is **not unique** in `building_2d`; it is unique only per `county_id`. The repair
  removed today's duplicates, it did not add a constraint.
- Of the 44 rows in the 18 multi-part groups, **23 hold no `building_2d` at all**. Only those three
  groups ever had more than one part holding building data. The other 15 carry no duplicates, and an
  import now assigns a building to a part by geometry, so they cannot acquire any the way these did.
- Re-generating models per county id materialises a model under each part holding that building —
  which after the repair is one part per building for these codes.

---

## 4. Rules for writing code against this data

| Situation | Do |
|---|---|
| Uploading `BuildingModel` / `Building` / `OrtoDatas` / `YearBuiltData` / `OccupancyData` | POST `updateitemsbycountyids` with a repeated `countyids` parameter — one occurrence per polygon part (`?countyids=73482&countyids=73485`; a single comma-separated value does **not** bind). The `code` endpoints now do the same thing server-side, so either is correct. |
| Deciding which part one item belongs to | Don't write it again. Read it from the `building_2d` row the reference is already filed under (`Query.CountyIdsByReferencesAsync` in `DiGi.GIS.WebAPI`), and fall back to `DiGi.GIS.PostgreSQL.Query.CountyId` — inside the part, else nearest, else largest overlap — only for something carrying geometry of its own. An item that neither can place is reported and left unwritten. |
| A background post task | Set `CountyId` on `BuildingModelsPostTask` / `BuildingsPostTask`; it takes precedence over `Code`. |
| Client already iterating counties | It is iterating **parts**. Use `AdministrativeAreal2DReference.Id`, and expect 406 entries, not 380. |
| Need to know a code is ambiguous | `AdministrativeAreal2DPostgreSQLConverter.GetIdsByCodeAsync` (returns every part). `GetIdByCodeAsync` collapses to the lowest and tells you nothing. |
| Need every building of a county | Query **each** part id — one part's `referencesbycountyid` is not the whole county. |
| Writing a new `SELECT … LIMIT`/`FirstOrDefault` here | Add `ORDER BY id ASC`. |
| Tempted to dedupe `administrative_areal_2d` | Don't. See §1 — the rows are geometry, not noise. |

---

## 5. Re-deriving any of this

Live checks (read-only GET, see [Coding - Deployed WebAPI.md](Coding%20-%20Deployed%20WebAPI.md)):

```bash
curl -s "https://api.digiproject.uk/gis/administrativeareal2d/idbycode?code=2212&administrativearealtype=2"
```

```bash
curl -s "https://api.digiproject.uk/gis/administrativeareal2d/administrativeareal2dreferencesbycode?code=2212"
```

`referencesbycode` returns every part; `idbycode` and `administrativeareal2dreferencebycode` return
one. Comparing the two is the quickest way to spot an ambiguous code.

Source-side check — count `powiat` features in a county package without extracting anything:

```python
import zipfile, io, re, collections
outer = zipfile.ZipFile(r"<path>/Polska_GML.zip")
with outer.open("BDOT10k/22_GML.zip") as stream:
    inner = zipfile.ZipFile(stream)
    names = {n.split("/")[-1]: n for n in inner.namelist()}   # entry naming is inconsistent
    package = zipfile.ZipFile(io.BytesIO(inner.read(names["2212_GML.zip"])))
name = next(n for n in package.namelist() if n.endswith("OT_ADJA_A.xml"))
xml = package.read(name).decode("utf-8")
print(collections.Counter(re.findall(r"<ot:rodzaj>([^<]*)</ot:rodzaj>", xml)))
```

Streaming a voivodeship costs ~3-12 s; the nested archives are stored effectively uncompressed, so
never extract them to disk.

---

## 6. Enum & wire gotchas

- `AdministrativeArealType`: `Undefined = -1`, `Country = 0`, `Voivodeship = 1`, `County = 2`,
  `Municipality = 3`, `Subdivision = 4`. Member 4 was misspelled `Subdivison` and was renamed — a
  breaking wire change with no alias kept, so `Subdivison` is now rejected. The value never changed,
  so nothing stored under `type_id` was affected. Integer `4` binds against any build; `Subdivision`
  only against a build carrying the rename.
- **`Undefined` is `-1`, not `0`, so it is not what an omitted parameter binds to.** A non-nullable
  `[FromQuery] AdministrativeArealType` left out of the request keeps `default(T)` — which is
  `Country`. A controller guard written as `administrativeArealType == AdministrativeArealType.Undefined`
  therefore never fires for the case it looks like it covers, and the request quietly returns countries:
  omitting the parameter on `administrativeareal2Dreferencesbyadministrativearealtype` returns a payload
  byte-identical to passing `0`. Bind it as `AdministrativeArealType?` and reject `null`. Same trap, and
  the fix, in [Coding - WebAPI Contracts.md](Coding%20-%20WebAPI%20Contracts.md) §2.
- `AdministrativeAreal2DReference.CountyId` is the **parent** county, so it is `null` on a county row.
  A county row's own identity is `Id`. `GetIds()` returns the chain plus `Id`.
- `GetBuilding2DReferencesByAdministrativeAreal2DIdsAsync` resolves through **Subdivision children**,
  not geometry. It returns an empty list for a county row that has no subdivisions — which is not the
  same thing as "no buildings there".
