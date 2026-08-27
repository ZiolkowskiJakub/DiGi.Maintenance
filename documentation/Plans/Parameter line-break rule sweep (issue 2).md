# Sweep declarations violating the `<= 7` parameter line-break rule (issue [DiGi.Maintenance#2])

> Portability note: all paths are DigiProject-root-relative and fully resolvable (`RepoName/ProjectName/.../File.cs:line`; `DiGi.PostgreSQL` hosts several projects — e.g. `DiGi.PostgreSQL.Table` — and `DiGi.Test` hosts the xUnit projects). Line
> numbers are as of 2026-08-27; re-run the strict scan (see Evidence) before editing, because
> converters in `DiGi.GIS.PostgreSQL` are moving weekly. Ten affected working trees were clean at
> time of review.

[DiGi.Maintenance#2]: https://github.com/ZiolkowskiJakub/DiGi.Maintenance/issues/2

---

## Verdict

**Still valid — implement it, with two corrections to the record.**

- **18 of the 19 listed entries are confirmed violations** as of 2026-08-27.
- **1 listed entry is a false positive** and must NOT be reflowed:
  `DiGi.Communication.WebAPI/DiGi.Communication.WebAPI/Create/ScatteringHitResult.cs:45` (`return new(`). The issue's
  heuristic recorded it as 1 parameter; the call actually has **13 arguments** (≥ 8), so the
  multi-line shape is **required** by the rule. Reflowing it would create the very violation the
  issue removes. Per `GitHub - Issues.md` §2 this needs a correcting comment.
- **The real declaration population is 30 in the `DiGi.*` suite, not 16** (plus the `TimGreatrexArchitect` add-in entry the issue lists separately — D4, excluded by default). The issue's heuristic (only matches a
  declaration whose opening `(` ends the line) missed 14 declarations:
  - **11 were committed after the issue's 2026-08-18 scan** — new code written *after* the rule
    change keeps reintroducing the exact pattern: `9940f4d` (2026-08-21, fallbackByReference),
    `5ddb536` (2026-08-25, OrtoDatasReference queries), `1fa60cc` (2026-08-25, identifier
    whitelisting), `b8eecec` (2026-08-21, controller hardening).
  - **3 predate the scan and were missed by the heuristic** — all are generic `<T>(...)`
    signatures with a trailing `where` clause: `DifferenceResult3D`, `UnionResult3D`
    (`b76df20`, 2026-07-09) and `TryBuildFilterGroupSql` (2026-06-23).
- **The rule is confirmed in all three canonical sources** — `Coding - General.md` §1.6 (Core
  Coding Rules, rule 6), `Coding - Editor Config.md` rule 4, and the root `CLAUDE.md` — identical
  wording: `<= 7` parameters stay on one line however long it gets; `>= 8` split one per line;
  declarations *and* call sites; line length is never the trigger.
- **The issue's "deep scan" request was executed** with a Roslyn `SyntaxTree` scan (the stricter
  pass the issue asks for), across the whole workspace, bin/obj/.vs/.git excluded, 0 parse errors.
  Its full findings are below, including the class of shapes the heuristic could never see.

**Conclusion:** the issue is valid and undercounts. Sweep all 30 in-scope declarations plus the two `return
Create(` call sites the issue itself listed (32 sites; 33 if D4 = include); leave the false positive alone; defer the much larger
call-site class and the enforcement question to explicit follow-up decisions.

---

## Decisions

| # | Decision | Where it lands |
|---|---|---|
| **D1** | Scope = **all 30 in-scope multi-line `ParameterList` declarations with 1-7 parameters** (the issue's 16 + 14 found by the strict scan) + the **two `return Create(` call sites** the issue listed = **32 sites, 10 repos**. The separately listed `TimGreatrexArchitect` declaration is D4 (excluded by default; +1 site if included). Whitespace-only reflow, parameter order untouched. | Implementation, 10 repos |
| **D2** | `ScatteringHitResult.cs:45` is **excluded** — 13 arguments, already compliant. Correct the record in a comment. | Issue hygiene 1 |
| **D3** | **189 pure call-site wraps** (e.g. `new Point2D(expr, expr)`), **288 embedded call sites** (multi-line lambda/object-initializer arguments — not reflowable without restructuring), **5 `ThemeInfo` WPF attributes**, **57 tuple/paren-expression shapes** are **out of scope**: the issue declares itself a declaration sweep and is tiered `ai: light`. The call-site question is a policy decision (reflowing expression-heavy calls yields 100-150-char lines) that should be settled together with the enforcement question, not silently swept across ~40 repos. | Not in this change; follow-up issue |
| **D4** | `TimGreatrexArchitect/Addin/Tim Greatrex Architect/Classes/ElementDataModel/ElementData.cs:19` **excluded — confirmed by the user** (scope fixed at 32 sites) — the issue says to include it "only if that addin is meant to follow these guidelines"; it is outside the `DiGi.*` suite. | Not in this change |
| **D5** | Enforcement decision (the issue asks for it): **`.editorconfig` cannot express this rule** — the shared repo `.editorconfig` template has no parameter-line-break option and no such option exists in the spec; `dotnet format` does not lay out parameter lists. The real enforcement path is a **custom Roslyn `DiagnosticAnalyzer`** (the scan in Evidence is a prototype of exactly that). That is an `ai: standard`-class project — **separate issue, not this one.** | Not in this change; follow-up issue |

---

## Evidence — the strict scan

Roslyn-based: `SyntaxTree.ParseText` (C# `Latest`) per file, then every `ParameterListSyntax`,
`ArgumentListSyntax`, `AttributeArgumentListSyntax` whose span crosses a line break with **1-7
top-level entries** (nested `()[]{}` and string/comment aware, unlike the issue's line heuristic),
plus a secondary pass over `TupleExpressionSyntax` / `ParenthesizedExpressionSyntax`.

| Class | Count | Disposition |
|---|---|---|
| `ParameterList` (declarations), 1-7 params | **31** (30 in the `DiGi.*` suite + 1 `TimGreatrexArchitect`) | 30 **in scope (D1)**; 1 D4-pending (excluded by default) |
| `ArgumentList`, all entries single-line (reflowable) | 189 (incl. the 2 `return Create(`) | 2 in scope (listed in the issue); 187 out of scope (D3) |
| `ArgumentList`, has a multi-line lambda/initializer entry | 288 | Out of scope — not reflowable without restructuring (D3) |
| `AttributeArgumentList` (WPF `ThemeInfo` boilerplate, 5 `AssemblyInfo.cs`) | 5 | Out of scope — standard template shape with aligned comments (D3) |
| Secondary: multi-line tuples / parenthesized expressions (mostly `Designer.cs` boilerplate) | 57 | Out of scope — a different visual class, not a parameter list (D3) |

The scan also explains the false positive: `ScatteringHitResult.cs:45` does **not** appear in the
≤ 7 argument list at all, because it has 13 arguments.

### In-scope list (32 sites, 10 repos, as of 2026-08-27 — 33 if D4 = include)

**DiGi.Communication.WebAPI** — branch 0.8.1 — 1

| Line | n | Origin |
|---|---|---|
| `DiGi.Communication.WebAPI/DiGi.Communication.WebAPI/Classes/Result/GeometricalPropagationResult.cs:24` | 6 | listed in the issue |

**DiGi.Core** — 0.8.8 — 1

| Line | n | Origin |
|---|---|---|
| `DiGi.Core/DiGi.Core/Classes/SphericalDistributionSerializableObjectCollection.cs:790` | 6 | listed in the issue |

**DiGi.Geometry** — 0.8.9 — 4

| Line | n | Origin |
|---|---|---|
| `DiGi.Geometry/DiGi.Geometry/Planar/Query/TryGetGridIndex.cs:20` | 7 | listed in the issue |
| `DiGi.Geometry/DiGi.Geometry/Spatial/Query/Intersect.cs:121` | 7 | listed in the issue |
| `DiGi.Geometry/DiGi.Geometry/Spatial/Create/DifferenceResult3D.cs:33` | 3 | missed by heuristic — generic `<T>()` + `where` (`b76df20`, 2026-07-09) |
| `DiGi.Geometry/DiGi.Geometry/Spatial/Create/UnionResult3D.cs:32` | 3 | missed by heuristic — generic `<T>()` + `where` (`b76df20`, 2026-07-09) |

**DiGi.Geometry.PointCloud** — 0.8.0 — 6

| Line | n | Origin |
|---|---|---|
| `DiGi.Geometry.PointCloud/DiGi.Geometry.PointCloud/Core/Classes/PointCloudIndex.cs:233` | 6 | listed in the issue |
| `DiGi.Geometry.PointCloud/DiGi.Geometry.PointCloud/Core/Modify/InsertNeighbor.cs:20` | 6 | listed in the issue |
| `DiGi.Geometry.PointCloud/DiGi.Geometry.PointCloud/Core/Query/NearestIndexes.cs:133` | 6 | listed in the issue |
| `DiGi.Geometry.PointCloud/DiGi.Geometry.PointCloud/Planar/Query/TryGetNearestIndexes.cs:20` | 6 | listed in the issue |
| `DiGi.Geometry.PointCloud/DiGi.Geometry.PointCloud/Spatial/Query/NearestIndexes.cs:18` | 6 | listed in the issue |
| `DiGi.Geometry.PointCloud/DiGi.Geometry.PointCloud/Spatial/Query/TryGetNearestIndexes.cs:21` | 7 | listed in the issue |

**DiGi.GIS** — 0.8.8 — 1

| Line | n | Origin |
|---|---|---|
| `DiGi.GIS/DiGi.GIS/Query/ElevationsAsync.cs:59` | 6 | listed in the issue |

**DiGi.GIS.Emgu.CV** — 0.8.8 — 1

| Line | n | Origin |
|---|---|---|
| `DiGi.GIS.Emgu.CV/DiGi.GIS.Emgu.CV/Classes/OrtoDatasComparison.cs:26` | 2 | listed in the issue |

**DiGi.GIS.PostgreSQL** — 0.8.8 — 11

| Line | n | Origin |
|---|---|---|
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/AdministrativeAreal2DReferencedObjectPostgreSQLConverter.cs:449` | 5 args | listed in the issue (was :386; line shifted) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/Building2DReferencedObjectPostgreSQLConverter.cs:1268` | 6 args | listed in the issue (was :524; line shifted) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/Building2DReferencedObjectPostgreSQLConverter.cs:373` | 7 | post-scan `1fa60cc` (2026-08-25) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/BuildingPostgreSQLConverter.cs:324` | 5 | post-scan `9940f4d` (2026-08-21) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/OrtoDatasPostgreSQLConverter.cs:320` | 5 | post-scan `9940f4d` (2026-08-21) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/OrtoDatasPostgreSQLConverter.cs:403` | 5 | post-scan `9940f4d` (2026-08-21) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/OrtoDatasPostgreSQLConverter.cs:831` | 4 | post-scan `9940f4d` (2026-08-21) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/OrtoDatasPostgreSQLConverter.cs:853` | 4 | post-scan `9940f4d` (2026-08-21) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/OrtoDatasPostgreSQLConverter.cs:1042` | 5 | post-scan `5ddb536` (2026-08-25) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/OrtoDatasPostgreSQLConverter.cs:1103` | 4 | post-scan `5ddb536` (2026-08-25) |
| `DiGi.GIS.PostgreSQL/DiGi.GIS.PostgreSQL/Classes/Converter/OrtoDatasPostgreSQLConverter.cs:1133` | 4 | post-scan `5ddb536` (2026-08-25) |

**DiGi.GIS.WebAPI** — 0.8.8 — 3

| Line | n | Origin |
|---|---|---|
| `DiGi.GIS.WebAPI/DiGi.GIS.WebAPI/Classes/Controller/EPWFileController.cs:29` | 2 | listed in the issue |
| `DiGi.GIS.WebAPI/DiGi.GIS.WebAPI/Classes/Controller/AdministrativeAreal2DController.cs:752` | 7 | post-scan `b8eecec` (2026-08-21) |
| `DiGi.GIS.WebAPI/DiGi.GIS.WebAPI/Classes/Controller/AdministrativeAreal2DController.cs:833` | 7 | post-scan `b8eecec` (2026-08-21) |

**DiGi.PostgreSQL** — 0.8.8 — 1

| Line | n | Origin |
|---|---|---|
| `DiGi.PostgreSQL/DiGi.PostgreSQL.Table/Query/TryBuildFilterGroupSql.cs:25` | 5 | missed by heuristic — generic `<T>()` + `where` (2026-06-23) |

**DiGi.Test** — 0.8.8 — 3

| Line | n | Origin |
|---|---|---|
| `DiGi.Test/DiGi.Analytical.xUnit/Facts/BuildingModelTrySplit.cs:22` | 6 | listed in the issue |
| `DiGi.Test/DiGi.Geometry.PointCloud.xUnit/Facts/PointCloudNearestIndexes.cs:281` | 7 | listed in the issue |
| `DiGi.Test/DiGi.Geometry.PointCloud.xUnit/Facts/PointCloudTriangle.cs:325` | 6 | listed in the issue |

---

## Not in this change

- **The 187 pure call-site wraps (D3).** Example of the class:
  `new Point2D(\n origin.X + t * direction.X,\n origin.Y + t * direction.Y)` — reflowing is
  legal under the letter of the rule but yields long lines, and the issue never declared call sites
  in scope. Decide the policy (and sweep, if chosen) in a follow-up issue, together with D5.
- **The 288 embedded call sites (D3).** `Parallel.ForEach(partitioner, i => { ... })` and
  `new X { ... }`-as-argument shapes. A single-line reflow is impossible without restructuring; the
  rule cannot govern them as written.
- **The 5 `ThemeInfo` attributes (D3).** WPF `AssemblyInfo.cs` template boilerplate whose standard
  form is exactly this wrapped shape with aligned trailing comments.
- **`TimGreatrexArchitect` (D4).** Outside the `DiGi.*` suite; the issue defers the call.
- **Analyzer enforcement (D5).** `.editorconfig` cannot express the rule (no such option exists;
  the shared repo `.editorconfig` template only sets `dotnet_style_operator_placement_when_wrapping`). A Roslyn
  `DiagnosticAnalyzer` can — the Evidence scan is a working prototype of it. File as its own issue:
  `type: enhancement`, `priority: medium`, `ai: standard` (`GitHub - Issues.md` §1,
  `GitHub - Labels.md`).

---

## Implementation

Per repo, one commit on the branch shown above. Whitespace-only edits:

1. **Reflow** each listed declaration/call onto one line: join the wrapped lines with a single
   space, keep every parameter/argument and its order exactly as-is (`Coding - General.md` §1.8 —
   `CancellationToken` stays last; XML `<param>` order stays mirrored). No reordering, no
   re-indentation of surrounding code, no comment edits.
2. **Preserve CRLF.** The edit tool writes LF into CRLF files and inflates diffs (lesson from the
   OrtoDatas plan) — after each edit check the file's line endings against `git show HEAD:<path>`
   and normalise back if mixed. Also: the edit tool **strips UTF-8 BOMs** — verify the first 3
   bytes against `git show HEAD:<path>` and restore (`ef bb bf`) if HEAD had one (hit in
   `DiGi.GIS.Emgu.CV/OrtoDatasComparison.cs`).
3. **Rebuild each affected repo** and confirm **zero warnings** (`Coding - General.md` §1.4).
   Watch for the `HintPath` parallel-build race: if a wall of bogus CS0246/CS0234 appears, rebuild
   with `-m:1`.
4. **Prove whitespace-only per repo:** `git diff --ignore-all-space` is *not sufficient* (a
   line-joining reflow still shows), and was wrong as stated here. The working proof is:
   `diff <(git show HEAD:<f> | tr -d '[:space:]') <(tr -d '[:space:]' < <f>)` empty for every
   touched file (no token changed), plus `git diff --numstat` showing exactly the expected
   reflow hunks, plus the BOM first-3-byte check from step 2.
5. **Re-run the strict scan** over the workspace: in-scope `ParameterList` hits must drop from 30 (31 if D4 = include)
   to **0**, with no new hits introduced.

Worked example — `EPWFileController.cs:29` before/after:

```csharp
// before
public EPWFileController(
    GISWebAPIConfigurationFileWatcher GISWebAPIConfigurationFileWatcher,
    EPWFilePostgreSQLConverter ePWFilePostgreSQLConverter)
// after
public EPWFileController(GISWebAPIConfigurationFileWatcher GISWebAPIConfigurationFileWatcher, EPWFilePostgreSQLConverter ePWFilePostgreSQLConverter)
```

```csharp
// before — AdministrativeAreal2DReferencedObjectPostgreSQLConverter.cs:449 (call site, 5 args)
return Create(
    npgsqlDataReader.GetInt32(0),
    npgsqlDataReader.IsDBNull(1) ? null : npgsqlDataReader.GetString(1),
    npgsqlDataReader.IsDBNull(2) ? null : npgsqlDataReader.GetString(2),
    JsonNode.Parse(npgsqlDataReader.GetString(3)) as JsonObject,
    npgsqlDataReader.IsDBNull(4) ? null : npgsqlDataReader.GetDateTime(4)
    );
// after
return Create(npgsqlDataReader.GetInt32(0), npgsqlDataReader.IsDBNull(1) ? null : npgsqlDataReader.GetString(1), npgsqlDataReader.IsDBNull(2) ? null : npgsqlDataReader.GetString(2), JsonNode.Parse(npgsqlDataReader.GetString(3)) as JsonObject, npgsqlDataReader.IsDBNull(4) ? null : npgsqlDataReader.GetDateTime(4));
```

Order of work: the 9 library repos first, `DiGi.Test` last (its three sites are private helpers
inside Facts — the affected test projects are `DiGi.Analytical.xUnit` and
`DiGi.Geometry.PointCloud.xUnit`).

---

## Verification

1. `dotnet build` in all 10 affected repos — **zero warnings, zero errors** (§1.4).
2. `git diff --ignore-all-space` empty in each repo (whitespace-only proof, step 4 above).
3. Re-run the strict Roslyn scan — **0** in-scope `ParameterList` hits; totals otherwise unchanged.
4. Run the two touched `DiGi.Test` projects (`dotnet test` on `DiGi.Analytical.xUnit` and
   `DiGi.Geometry.PointCloud.xUnit`) — the changed methods are private test helpers, so passing
   is the expectation; a failure means a reflow broke a signature, which step 2 should already
   have caught.
5. No deployment step — no public signature changed, so deployed endpoints are unaffected
   (`Coding - Deployed WebAPI.md` does not apply).

---

## Issue hygiene

1. **Correcting comment on #2** (`GitHub - Issues.md` §2) via `--body-file` with a UTF-8 no-BOM
   scratch file — never inline `--body` (PowerShell eats the backticks):
   - `ScatteringHitResult.cs:45` is a **false positive** — 13 arguments, already compliant;
     reflowing it would violate the rule. Evidence: the Roslyn argument count.
   - The declaration population in the `DiGi.*` suite is **30, not 16** (plus the separately listed `TimGreatrexArchitect` entry — D4) — 11 of the 14 additions were committed after
     the scan (`9940f4d`, `5ddb536`, `1fa60cc`, `b8eecec`), 3 were heuristic misses (generic
     `<T>()` signatures with `where` clauses).
2. **Labels:** `type: refactor` and `priority: medium` stay. `ai: light` stays — per-site work is
   still trivial; the extra sites do not change the tier. Labels are edited on open issues only.
3. **Follow-up issues** (each with `type:` + `priority:` + exactly one `ai:` tier):
   - D5: Roslyn analyzer to enforce the rule — `type: enhancement`, `priority: medium`, `ai: standard`.
   - D3: the call-site class (189 reflowable + 288 embedded) — decide the policy and sweep, or
     amend the rule text to scope it to declarations — `type: refactor`, `priority: medium`, `ai: standard`.
4. **On close**, the four-part resolution structure from `GitHub - Issues.md` §3: commits per repo,
   summary of the 32 reflows (33 if D4 = include), the verification results (steps 1-4), and the two follow-up issues
   linked.

---

## Status

**Implemented and closed** on 2026-08-27. D4 confirmed by the user: **exclude**
`TimGreatrexArchitect` (scope fixed at 32 sites). D1-D3 and D5 were settled by the evidence above.
Commits are local on each repository's version branch; **not pushed** (no push was requested).

| step | state |
|---|---|
| Correcting comment on #2 | done — [issue #2 comment](https://github.com/ZiolkowskiJakub/DiGi.Maintenance/issues/2#issuecomment-5437597787) |
| 10 repo reflows, one commit each | done — `1039880` (Comm.WebAPI 0.8.1), `237a2dc` (Core 0.8.8), `d5705a1` (Geometry 0.8.9), `cea9cfe` (PointCloud 0.8.0), `bd73a75` (GIS 0.8.8), `4b3f660` (GIS.Emgu.CV 0.8.8, BOM restored before commit), `191d740` (GIS.PostgreSQL 0.8.8), `f481c15` (GIS.WebAPI 0.8.8), `2913262` (PostgreSQL 0.8.8), `544dbfa` (Test 0.8.8) |
| Zero-warning rebuilds + whitespace-only proof | done — 0 warnings / 0 errors in all 10 builds; whitespace-stripped diff vs HEAD empty for all 14 files; BOM first-3-byte check passed; `numstat` = exactly the 32 expected hunks |
| Strict scan re-run → 0 in-scope hits | done — 0 wrapped 1-7 parameter declarations left in the `DiGi.*` suite; remaining wrapped declarations are 8-parameter (compliant) and the excluded `TimGreatrexArchitect` entry |
| `DiGi.Analytical.xUnit` + `DiGi.Geometry.PointCloud.xUnit` pass | done — 47/47 and 59/59 passed |
| Follow-up issues filed (D5 analyzer, D3 call sites) | done — [DiGi.Maintenance#4](https://github.com/ZiolkowskiJakub/DiGi.Maintenance/issues/4) (`type: enhancement`, `priority: medium`, `ai: standard`), [DiGi.Maintenance#5](https://github.com/ZiolkowskiJakub/DiGi.Maintenance/issues/5) (`type: refactor`, `priority: medium`, `ai: standard`) |
| Close #2 with §3 resolution comment | done — [issue #2 resolution comment](https://github.com/ZiolkowskiJakub/DiGi.Maintenance/issues/2#issuecomment-5437605164); #2 CLOSED, labels unchanged (`type: refactor`, `priority: medium`, `ai: light`) |
