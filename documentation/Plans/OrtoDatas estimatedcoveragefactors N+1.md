# `gis/ortodatas/estimatedcoveragefactors` — N+1 catalog reads (issue [DiGi.GIS.WebAPI#9])

> Portability note: all paths are repo-relative (`RepoName/.../File.cs:line`). Each `DiGi.*` repo is
> a separate project on branch `0.8.8`; all four affected working trees were clean at time of review
> (2026-08-26).

[DiGi.GIS.WebAPI#9]: https://github.com/ZiolkowskiJakub/DiGi.GIS.WebAPI/issues/9

---

## Verdict

**Valid — implement it. But the severity claim in the issue body is wrong and must be corrected
first.**

The structural defect is exactly as described and violates `AI Guidelines/Coding - PostgreSQL.md` §3
verbatim ("NEVER execute individual SQL queries inside a loop over a collection"). The *consequence*
described — "roughly 760 sequential round trips, each at the 30 second Npgsql default", implying
timeouts — does not reproduce. The database is co-located with the API host, so each catalog read
costs ~0.2 ms and the whole-country request finishes in under half a second.

Per `AI Guidelines/GitHub - Issues.md` §2 the record gets corrected in a comment before the fix
lands, because a closed issue keeps teaching whatever it last said.

### Measured on the deployed API, 2026-08-26

Host build `DiGi.GIS.WebAPI 0.8.8` commit `2d13c26`, three commits behind local `c12e2fa`; neither
loop changed in between, so the deployed code is the code under review.

| request | measured | statements issued |
|---|---|---|
| `POST estimatedcoveragefactors` body `[5]` (one county) | 21.1 / 22.0 / 20.7 ms | ~4 |
| `POST estimatedcoveragefactors` body `[7]` (Polska) | 447 ms, 351 ms | ~1 624 |
| `GET estimatedcoveragefactor?administrativeareal2Did=7` | 383 ms | ~1 624 |

Both country-level forms answered `200` with a real aggregate (`0.4986`), so the expansion genuinely
visited every county — `administrativeareal2Dreferencesbyadministrativearealtype=2` returns **406**
rows (380 codes; the extra 26 are polygon parts of multi-part counties, see
`AI Guidelines/Coding - GIS Administrative Data.md`).

The issue undercounts the statements. Each `GetEstimatedCountAsync` call is **two** round trips, not
one — `Query.EstimatedCountAsync` calls `TableExistsAsync` and then reads `pg_class` — so 406
counties × 2 tables = 812 converter calls = ~1 624 statements plus 812 pooled connection opens. The
marginal cost works out at ~0.47 ms per converter call.

**Conclusion:** the endpoint is 20× more expensive than it needs to be and breaks a stated rule, but
it is not currently timing out and `priority: high` overstates it.

---

## Decisions (settled 2026-08-26)

| # | Decision | Where it lands |
|---|---|---|
| **D1** | `analyze=true` is **documented and timed out, not capped**. No threshold guard, and the flag stays on both endpoints — removing it would be a breaking wire change. | Phase 1 step 3, Phase 3, *Not in this change* |
| **D2** | The zero-scoring defect (F6) becomes **its own issue**, filed and linked from #9. This change stays behaviour-preserving. | *Not in this change*, Issue hygiene 3 |
| **D3** | #9 is relabelled **`priority: high` → `priority: medium`**, with the measurements recorded in the correcting comment. | Issue hygiene 1–2 |
| **D4** | The three sibling converters are **in scope** for this change. | Phase 4 |

---

## Status — implemented 2026-08-26, uncommitted

Phases 1-4 and the tests are done and build clean across all four repos (0 warnings, 0 errors).
**Nothing is committed and nothing is deployed**, so the production verification below has not run.

| step | state |
|---|---|
| Correcting comment on #9, relabelled `priority: medium` | done |
| Follow-up issue for F6 filed and linked | done - [DiGi.GIS.PostgreSQL#44](https://github.com/ZiolkowskiJakub/DiGi.GIS.PostgreSQL/issues/44) |
| Phase 1 `DiGi.PostgreSQL` | done - new `Query/EstimatedCountsAsync.cs`, `commandTimeout` + quoted identifier on the singular, `CancellationToken` on `TableExistsAsync` |
| Phase 2 `DiGi.GIS.PostgreSQL` | done - batched plural + re-seated summing plural on `OrtoDatas` and `Building2D` |
| Phase 3 `DiGi.GIS.WebAPI` | done - three loops replaced by two batched reads, `commandtimeout` on both coverage endpoints |
| Phase 4 siblings | done - `Building`, `Building2DReferencedObject`, `TerrainPoint`; F8 guard added |
| Tests | done - 3 + 180 + 30 pass, 30 integration skipped |
| Commit / deploy / production verification / close #9 | **not started** |

Three things turned up during implementation that the plan did not predict:

- **The `commandtimeout` fix on `BuildingController`, `TerrainController` and
  `OrtoDatasController.GetCountByCountyIdAsync` only wired the `estimated=true` branch.** Checking the
  `estimated=false` (exact `COUNT(*)`) sibling turned up the same defect one layer down:
  `Query.CountAsync` has no `commandTimeout` parameter at all, so nothing above it can forward one -
  and that is the branch that actually needs a timeout, since an exact count on a large partition is a
  sequential scan where the `pg_class` estimate is ~0.2 ms. `BuildingDataController` plumbs the
  parameter correctly through two layers and drops it only at the final `Query.CountAsync` call.
  Filed separately as [DiGi.PostgreSQL#2](https://github.com/ZiolkowskiJakub/DiGi.PostgreSQL/issues/2)
  and linked from #9 - it is a same-sized migration (~15 signatures, 17 + 9 call sites) touching
  converters outside this issue's scope, and keeping this change behaviour-preserving is what makes
  the "factor must not move" verification below meaningful.

- **15 CS1503 sites, not 16.** The predicted worklist was otherwise exact.
- **`BuildingController`, `TerrainController` and `OrtoDatasController.GetCountByCountyIdAsync` each
  already accepted a `commandtimeout` query parameter and silently dropped it** on the estimated
  branch - they passed `analyze, cancellationToken` positionally and never forwarded the timeout.
  Those three endpoints have advertised a parameter that did nothing since #12. Now wired.
- **The Edit tool writes LF into CRLF files.** Two converters came out with mixed endings, inflating
  their diffs by 13 lines each. Both were CRLF at `HEAD` (verified with `git show HEAD:<path>`), so
  they were normalised back; `git diff --ignore-cr-at-eol` now matches `git diff` exactly everywhere.

**F8 was reproduced before it was fixed**, as `Coding - Automatic Tests.md` §4 requires: reverting the
guard and running `GetEstimatedCountAsync_NullCountyIds_ReturnsMinusOne` fails with
`System.NullReferenceException` thrown from
`Building2DReferencedObjectPostgreSQLConverter.GetEstimatedCountAsync` line 158, and passes once the
guard is restored. The fact needs no database - the connection is never opened.

---

## Findings

| # | Sev | Finding | Evidence |
|---|-----|---------|----------|
| **F1** | Med | **The N+1 the issue names.** Three loops in `GetEstimatedCoverageFactorsAsync` call the per-county `GetEstimatedCountAsync` once per county per table. | `DiGi.GIS.WebAPI/.../OrtoDatasController.cs:282-351` |
| **F2** | Med | **A second N+1 one layer down.** The plural `GetEstimatedCountAsync(IEnumerable<int>)` on both converters loops internally and returns a single sum. The issue notes this; what it does not note is that the **GET** sibling `estimatedcoveragefactor` reaches the same 812 calls through it, so fixing only the controller leaves half the problem. | `OrtoDatasPostgreSQLConverter.cs:85-110`, `Building2DPostgreSQLConverter.cs:212-239`, controller `:174-175` |
| **F3** | Med | **Connection churn.** The instance `GetEstimatedCountAsync(int?)` opens and closes an `NpgsqlConnection` per call — 812 pooled opens per country request. The plural at least reuses one. | `OrtoDatasPostgreSQLConverter.cs:511-521`, `Building2DPostgreSQLConverter.cs:1588-1598` |
| **F4** | Med | **No `commandTimeout` on either coverage endpoint or anywhere beneath them**, against §3's "all methods executing database queries … must expose an optional `int commandTimeout`". `Query.EstimatedCountAsync` has none either, so every statement runs at the Npgsql 30 s default. Sibling endpoints in the same controller (`countbycountyid`, added for #12) already take `commandtimeout`. | `OrtoDatasController.cs:211,407`; `DiGi.PostgreSQL/Query/EstimatedCountAsync.cs:17` |
| **F5** | **High** | **`analyze=true` is the real hazard, and it is not a round-trip problem.** It issues one `VACUUM ANALYZE` per partition — 812 of them for a country, sequentially, at the 30 s default, on full production partitions. Batching cannot remove this work; only a timeout and a documented contract can bound it. Untested against production, deliberately. | `Query/EstimatedCountAsync.cs:29-36` |
| **F6** | **High** | **Correctness: unanalysed partitions are silently counted as zero.** The summing plural keeps only `count > 0`, so both `null` (no partition) and `-1` (partition never analysed) drop out — independently per table. A county whose `building_2d_X` is analysed but whose `orto_datas_X` is not contributes buildings to the denominator and nothing to the numerator, pulling the reported factor down with no warning. The measured `0.4986` for Polska is therefore a **lower bound**, not a measurement. Deliberate, not accidental — `TerrainPointPostgreSQLConverter.cs:163-168` states the intent in a comment. | `OrtoDatasPostgreSQLConverter.cs:104-107`, `Building2DPostgreSQLConverter.cs:231-234` |
| **F8** | Med | **`Building2DReferencedObjectPostgreSQLConverter.cs:105` NREs on a null `countyIds`** — alone among the plurals it has no null guard, and alone among them it is an instance rather than a static method. Found while sizing Phase 4; unrelated to #9. | `Building2DReferencedObjectPostgreSQLConverter.cs:105-123` |
| **F7** | Low | `GetAdministrativeAreal2DReferencesByParentCodeAsync` is called without its `cancellationToken`, against `Coding - General.md` §8 ("pass by name"). A cancelled country request keeps expanding. | `OrtoDatasController.cs:317` |

---

## Design

Both figures are one grouped catalog read per database. `pg_class.reltuples` already carries the
whole answer for a set of partitions, and it carries the *unanalysed* signal too: PostgreSQL 14+
stores `-1` for a relation that has never been analysed, which is exactly the `-1` the singular
method already documents. Reading the catalog by name also makes `TableExistsAsync` redundant — a
partition that does not exist simply produces no row.

```sql
SELECT c.relname, c.reltuples
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p')
  AND c.relname = ANY(@tableNames);
```

**Return shape.** `Dictionary<string, long>?` at the generic layer, `Dictionary<int, long>?` keyed by
county id at the converter layer:

- `null` return — no connection, or no input.
- **key absent** — no such partition (what the singular returns as `null`).
- **value `-1`** — partition exists, never analysed (what the singular returns as `-1`).
- **value ≥ 0** — the planner's estimate.

This preserves both distinctions the singular carries, which the issue's proposed
`Dictionary<int, long>`-of-plain-counts would have collapsed. It is also what F6 needs in order to be
fixable: a caller can finally tell "no orthophotos here" from "nobody has analysed this partition".

**Where the code goes.** The batched read is not GIS-specific, so it belongs beside its singular
sibling in `DiGi.PostgreSQL/Query/`, one public method per file named after the method
(`Coding - General.md` §2, File Organisation). The two GIS converters then only map county id to
table name and back — they never re-parse the `_<id>` suffix, because the request is built from a
`name → countyId` dictionary that is kept for the reply.

**Dynamic identifiers.** Table names are composed from `int` county ids, so they cannot carry
injected SQL — but the `VACUUM ANALYZE` path still gets the §5 treatment on principle: only names
that **came back from the catalog read** are vacuumed (the catalog is the whitelist), and they are
double-quoted. The current singular interpolates the name into `VACUUM ANALYZE {tableName}` unquoted.

---

## Implementation

### Phase 1 — `DiGi.PostgreSQL` (base layer)

**New** `DiGi.PostgreSQL/DiGi.PostgreSQL/Query/EstimatedCountsAsync.cs`:

```csharp
public static async Task<Dictionary<string, long>?> EstimatedCountsAsync(this NpgsqlConnection? npgsqlConnection, IEnumerable<string>? tableNames, bool analyze = false, int batchSize = 1000, int commandTimeout = 600, CancellationToken cancellationToken = default)
```

Six parameters, so it stays on one line (`Coding - General.md` §1.6); `commandTimeout` before the
token (§1.8 / CA1068). Body:

1. Materialise, drop blanks, de-duplicate.
2. Chunk at `batchSize` and read the catalog with `ANY(@tableNames)` typed
   `NpgsqlDbType.Array | NpgsqlDbType.Text` (§3, Query Batching Pattern). At today's 406 names this
   is a single round trip; the chunk loop is there so it stays one *bounded* statement at any scale.
3. `analyze == true`: for each name **present in the result**, run `VACUUM ANALYZE "<name>"` with
   `commandTimeout`, then re-run step 2 for those names. Note in the XML `<summary>` that this is one
   statement per table by construction and cannot be batched.
4. `await using` on every command and reader; `cancellationToken` on every async Npgsql call (§4).
5. `reltuples` arrives as `float4` — reuse the singular's numeric-widening ladder.

**Modify** `Query/EstimatedCountAsync.cs`:
- add `int commandTimeout = 600` before the token, assign it to both commands;
- quote the identifier: `VACUUM ANALYZE "{tableName}"`;
- pass `cancellationToken:` to `TableExistsAsync`.

**Modify** `Query/TableExistsAsync.cs`: append `CancellationToken cancellationToken = default` to
both overloads and pass it to `ExecuteScalarAsync`. Appending at the end breaks no call site.

> Adding `commandTimeout` to the singular turns every positional
> `EstimatedCountAsync(conn, name, analyze, cancellationToken)` into **CS1503** — a token will not
> bind to an `int`. That is the desired outcome: the compiler produces the exact worklist, nothing
> misbinds silently. Sites to fix with `cancellationToken:` naming (§1.8):
> `AdministrativeAreal2DPostgreSQLConverter.cs:1002,2063`,
> `AdministrativeAreal2DReferencedObjectPostgreSQLConverter.cs:78,97`,
> `Building2DPostgreSQLConverter.cs:201,230`, `Building2DReferencedObjectPostgreSQLConverter.cs:94,116`,
> `BuildingDataPostgreSQLConverter.cs:551`, `BuildingPostgreSQLConverter.cs:204,232`,
> `OrtoDatasPostgreSQLConverter.cs:74,102`, `TerrainPointPostgreSQLConverter.cs:117,163`.

### Phase 2 — `DiGi.GIS.PostgreSQL` (converters)

In **both** `OrtoDatasPostgreSQLConverter.cs` and `Building2DPostgreSQLConverter.cs`:

```csharp
public static async Task<Dictionary<int, long>?> GetEstimatedCountsAsync(NpgsqlConnection? npgsqlConnection, IEnumerable<int>? countyIds, bool analyze = false, int batchSize = 1000, int commandTimeout = 600, CancellationToken cancellationToken = default)
public async Task<Dictionary<int, long>?> GetEstimatedCountsAsync(IEnumerable<int>? countyIds, bool analyze = false, int batchSize = 1000, int commandTimeout = 600, CancellationToken cancellationToken = default)
```

Plural name `GetEstimatedCountsAsync` — no collision with the existing
`GetEstimatedCountAsync(IEnumerable<int>)`, so no CS0121 and no caller breaks.

- **Rewrite the existing summing plural** to call the new one and sum, **keeping its signature and
  its skip-non-positive semantics unchanged**. This is what fixes F2 for the GET endpoint and for
  every other caller without touching them.
- Add `commandTimeout` to the singular static and instance `GetEstimatedCountAsync` (F4), mirroring
  `BuildingDataPostgreSQLConverter.cs:535`, which already has it.

### Phase 3 — `DiGi.GIS.WebAPI` (`OrtoDatasController`)

`GetEstimatedCoverageFactorsAsync` (`:211`) gains `[FromQuery(Name = "commandtimeout")] int
commandTimeout = 600` before the token — four parameters, still one line — and is restructured to:

1. classify the references into county / subdivision-municipality / voivodeship-country (unchanged);
2. expand each voivodeship/country to its county ids, **passing `cancellationToken:`** (F7). This
   loop stays: it is bounded by the number of voivodeship/country ids in the request, not by 406;
3. union every county id needed into one `HashSet<int>`;
4. **two** calls — `building2DPostgreSQLConverter.GetEstimatedCountsAsync(…)` and
   `ortoDatasPostgreSQLConverter.GetEstimatedCountsAsync(…)`;
5. assemble the per-identifier pairs from the two maps; a key absent from a map becomes `-1`, which
   preserves today's "unknown reads as factor 0" behaviour;
6. the `estimatedCoverageFactor` lambda and the ordered result assembly are unchanged.

Statement count drops from ~1 624 to **2**, plus one reference read per voivodeship/country.

`GetEstimatedCoverageFactorAsync` (`:104`, the GET sibling) needs only the `commandtimeout`
parameter and the named `cancellationToken:` — it inherits the fix through the rewritten summing
plural.

### Phase 4 — sibling converters (D4: in scope)

The same summing loop is in `BuildingPostgreSQLConverter.cs:215`,
`Building2DReferencedObjectPostgreSQLConverter.cs:105` and `TerrainPointPostgreSQLConverter.cs:147`.
Each is ~10 lines to re-seat on the Phase 1 method, and all three ship in this change — one build,
one review, one deploy, and the pattern stops spreading. They are **not** part of the defect #9
reports, so name them separately in the resolution comment rather than letting them read as such.

Two of the three deviate from the `OrtoDatas` / `Building2D` shape, so do not re-seat them by
copy-paste:

- **`Building2DReferencedObjectPostgreSQLConverter.cs:105` is an *instance* method** (the others are
  `static`), takes a non-nullable `IEnumerable<int>`, and carries **no null guard** — a null argument
  reaches the `foreach` and throws `NullReferenceException` rather than returning `-1` like every
  sibling. Add the guard while re-seating it; that is a fix, not a refactor, so call it out.
- **`TerrainPointPostgreSQLConverter.cs:147`** takes `IEnumerable<int>?` and its null branch returns
  the **parent** table estimate. Preserve that branch exactly — the terrain count endpoints reach it.

Note also that `TerrainPointPostgreSQLConverter.cs:163-168` documents the F6 skip in a comment
("contributes nothing to the sum rather than subtracting"). F6 is therefore a **deliberate choice
being revisited**, not an oversight being corrected — frame the follow-up issue that way.

### Not in this change

**F6 goes to its own issue (D2).** Now that the batched shape distinguishes "absent" from `-1`, the
endpoint *could* report an unanalysed partition instead of silently scoring it zero — but that alters
what a deployed client receives. File it, link it from #9, and land the batching first. Keeping this
change behaviour-preserving is exactly what gives the equivalence test and the "factor must not move"
check in Verification their meaning; fold F6 in and both stop being able to catch a mistake.

**F5 is documented, not capped (D1).** No "skip analyze above N counties" guard — that is
temporary-code-shaped and would need a `TODO [Marker]` plus a removal condition
(`Coding - General.md` §1.12) for a limit nobody intends to remove. `analyze` also stays on both
endpoints; dropping the query parameter would be a breaking wire change for any existing caller.
Instead: expose `commandtimeout`, and state in the XML `<summary>` that `analyze=true` costs one
`VACUUM ANALYZE` per resolved partition — 812 for a country — so the caller owns the decision with
the price in front of them.

---

## Tests (`DiGi.Test`, branch 0.8.8)

`Coding - Automatic Tests.md` §4 asks for a `[Fact]` that fails on unmodified code with the reported
symptom. **The reported symptom here is a statement count, not a wrong answer**, and there is no
statement counter in the harness — so state that plainly rather than dressing a latency assertion up
as a reproduction. What is testable:

**`DiGi.PostgreSQL.xUnit/Facts/EstimatedCountsAsync.cs`**
- null connection → `null`; null names → `null`; empty names → empty dictionary.
- an unknown table name is **absent** from the dictionary, not present as `0`. This is the contract
  that keeps F6 fixable.

**`DiGi.GIS.PostgreSQL.xUnit/Facts/GetEstimatedCountsAsync.cs`**
- `new OrtoDatasPostgreSQLConverter(null).GetEstimatedCountsAsync([5, 6])` → `null`, matching the
  no-connection convention already used in `BuildingDataPostgreSQLConverter.cs:45`.
- **Equivalence, integration, `[Fact(Skip = "…")]`** per the existing convention in that project:
  for ~20 county ids, assert the batched dictionary agrees with the per-county singular results,
  including the absent-vs-`-1` cases. This is the fact that proves the rewrite is behaviour-preserving.
- **Latency, integration, skipped:** batched vs looped over the same county ids, measured isolated
  (`dotnet test -c Release --filter "FullyQualifiedName~…"`), three runs, report the range.

> These integration facts run against a `*.conf`, which is a **development** database
> (`Coding - PostgreSQL.md` §6). They prove the statement shape and the equivalence. They prove
> nothing about the estate — the production numbers come from the API, below.

---

## Verification

1. Build all four repos. Watch for the `HintPath` parallel-build race: if a wall of bogus
   CS0246/CS0234 appears, rebuild with `-m:1`.
2. Run both new xUnit projects; zero warnings (`Coding - General.md` §1.4).
3. Deploy, confirm the host is actually serving the new build before measuring anything —
   `GET /information/controllers`, compare `InformationalVersion`'s commit hash against `git log`
   (`Coding - Deployed WebAPI.md` §1).
4. Re-run the two production measurements and compare against the 2026-08-26 baselines above:

```bash
curl -s -o /dev/null -w "%{time_total}\n" -X POST "https://api.digiproject.uk/gis/ortodatas/estimatedcoveragefactors" -H "Content-Type: application/json" -d "[7]"
```

   Baseline 351–447 ms; expect the country request to land near the one-county figure (~21 ms), since
   the remaining cost is two catalog reads plus HTTP.

5. **The factor must not move.** `[7]` returned `0.49860497791638586` and the GET form
   `0.49859407609346473` (they differ only because `reltuples` drifts between reads). A materially
   different value after the change means the rewrite altered the aggregation, not just its shape.
6. Run the endpoint sequentially, never concurrently, while measuring — concurrent calls against the
   terrain endpoints have exhausted a connection pool before, and only a service restart cleared it.
7. Leave `analyze=true` alone against production.

---

## Issue hygiene

1. Comment on #9 with the measured table and the F2/F5/F6 findings, correcting the "each at the 30
   second Npgsql default" impact claim (`GitHub - Issues.md` §2). Use `--body-file` with a UTF-8
   no-BOM scratch file — never `--body "…"`, the backticks in this text would be eaten by PowerShell.
2. Relabel `priority: high` → `priority: medium` (D3). Labels are edited on open issues only.
3. File the F6 follow-up (D2) against `DiGi.GIS.PostgreSQL` — the defect is in the converter, not the
   controller — and link it from #9. Every new issue needs a `type:`, a `priority:` and exactly one
   `ai:` tier (`GitHub - Issues.md` §1, `GitHub - Labels.md`): `type: bug`, `priority: medium`,
   `ai: standard`.
4. On close, use the four-part resolution structure from `GitHub - Issues.md` §3: commits, summary of
   changes, tests added, live deployed verification.
