# AI Guidelines: GitHub Sub-Issues (Tracking-Issues Pattern)

How sub-tasks are logged as GitHub sub-issues across the DiGi repositories.

**Canonical example** — the *External Components Area* feature:
- Parent (tracking issue): [DiGi.GIS.PostgreSQL #83](https://github.com/ZiolkowskiJakub/DiGi.GIS.PostgreSQL/issues/83)
- Sub-issues: [DiGi.GIS.IO #11](https://github.com/ZiolkowskiJakub/DiGi.GIS.IO/issues/11) (column definitions) · [DiGi.GIS.PostgreSQL #82](https://github.com/ZiolkowskiJakub/DiGi.GIS.PostgreSQL/issues/82) (computation + domain task) · [DiGi.GIS.PostgreSQL.UI #12](https://github.com/ZiolkowskiJakub/DiGi.GIS.PostgreSQL.UI/issues/12) (UI task)

Whenever the user asks to create **sub-issues** or **sub-tasks** for a feature, use this pattern — do not create a flat pile of independent issues.

---

## 1. When to use the pattern

- The feature spans **two or more repositories**, or has two or more independent workstreams that must stay coordinated (e.g. definitions → computation → UI).
- The shared design (rules, naming decisions, data flow) must survive as a **single source of truth**, while each repository carries only its own slice.
- One issue cannot cleanly hold both the feature design and the per-repository implementation scope.

Single-repo, single-workstream work stays a plain issue (`GitHub - Issues.md`).

## 2. Roles

| Role | What it is | Where |
|---|---|---|
| **Tracking issue** (parent) | The feature itself: shared spec, data flow, decisions, end-to-end acceptance, and the Sub-issues table. Owns no implementation scope of its own. | The repository that **owns the feature's core logic / data flow** (in the example: DiGi.GIS.PostgreSQL, where the computation task lives) |
| **Sub-issue** (child) | One repository's slice of the feature, self-contained enough to implement without reading the other repos. | One per affected repository |

## 3. Parent (tracking issue) structure

Sections, in this order (as in #83):

1. `## Summary` — the feature in a few lines plus bullets; names the new public artefacts (task, endpoint, column group, …).
2. **Domain spec sections** — whatever every sub-issue implements, stated once: the spec table(s), the classification / boundary rules, and a `## Data flow` code block showing the pipeline end to end.
3. `## Sub-issues` — the cross-repository index table (mandatory; format below).
4. `## Decisions` — naming and collision calls, boundary ownership, what is explicitly **out of scope** and possible follow-ups.
5. `## Acceptance criteria` — an **end-to-end** checklist covering the whole feature (not any single repository).

### The Sub-issues table (mandatory format)

```markdown
## Sub-issues

| Repository | Issue | Scope |
|---|---|---|
| DiGi.GIS.IO | #11 | `External Components Area` category + 35 static `Column.External*` fields (+ helper), uniqueness vs existing columns |
| DiGi.GIS.PostgreSQL | #82 | `Modify.Update_ExternalComponentsArea` classification + background task (options, batching, counters, latest-model-wins) |
| DiGi.GIS.PostgreSQL.UI | #12 | UI wrapper task, options window, registration in `VisualBackgroundTasks.cs` |
```

Rules for the table:
- **One row per sub-issue**, in **dependency order** (definitions → computation → presentation).
- `Issue` cell: the bare `#number` (the repository is already in the first column).
- `Scope`: **one line** — the deliverables that repository gets, with the key type / method names.

## 4. Sub-issue (child) structure

Sections, in this order (as in #11 / #82 / #12):

1. `## Context` — **mandatory first section**. The first sentence is always:

   > This is a sub-issue of the *\<Feature Name\>* tracking issue (\<parent repository\>).

   — use `(this repository)` when the parent lives in the same repo. Then 1–3 sentences: which **part** of the feature this sub-issue owns, and **which sibling sub-issue** owns the rest (name the sibling's repository). This is also why the parent must *name the feature* in its title/summary — the feature name is the shared identifier children reference by.
2. `## Scope` (or `## Part 1 — …` / `## Part 2 — …` when large) — the work in this repository only: exact type names, file paths, code sketches, boundary rules, single-source constants. **Self-contained:** details this repository needs to implement (exact name tables, thresholds, formulas) are repeated here — never "see parent" for implementable detail.
3. `## Tests` (`DiGi.Test`) — when the slice has logic: the `[Fact]` list, including boundary cases.
4. `## Acceptance criteria` — a **local** checklist, each item verifiable inside this repository alone.

## 5. Cross-referencing rules

| Direction | Mechanism |
|---|---|
| Parent → every child | The `## Sub-issues` table lists all of them with real issue numbers |
| Child → parent | The `## Context` first sentence names the *feature* + parent repository |
| Child → siblings | `## Context` states which sibling repository owns which part |

No issue comments are needed for the wiring — the structure lives in the bodies.

## 6. Creation workflow

1. **Design first.** Write the parent body (summary, domain spec, data flow, decisions, end-to-end acceptance) to a UTF-8 (no BOM) markdown file with LF newlines (`GitHub - Issues.md` §1 rules).
2. **Decompose.** One sub-issue per repository, in dependency order; every slice independently implementable; the union of the slices covers the parent's acceptance with no overlap.
3. **Create the parent** in the owning repository with the mandatory `type:` / `priority:` / `ai:` labels and default assignee `ZiolkowskiJakub` (`GitHub - Issues.md` §1), leaving the Sub-issues table with placeholder rows.
4. **Create each sub-issue** in its own repository — each with its **own** mandatory labels and assignee. Re-tier the `ai:` complexity per sub-issue from its own scope (`GitHub - AI Issue Classification.md` §3); do not copy the parent's tier.
5. **Fill in the parent's table** with the real issue numbers and one-line scopes (`gh issue edit … --body-file …`).
6. **Verification pass** before reporting done:
   - every sub-issue's `## Context` first sentence names the feature + parent repository;
   - the parent's table has exactly one row per sub-issue, in dependency order;
   - each sub-issue is self-contained for its repository (spec details repeated, not deferred);
   - every parent acceptance criterion is covered by at least one sub-issue's scope.

## 7. Lifecycle

- The parent stays **open while any sub-issue is open** — it is the umbrella.
- Close sub-issues as they land, each with the standard resolution comment (`GitHub - Issues.md` §3).
- **Check off the parent's acceptance criteria** as the corresponding sub-issues close.
- **Close the parent last**, with a resolution comment that summarises all sub-issue numbers and their commits.

## 8. Anti-patterns

- **Flat pile of independent issues** for one feature — no shared spec, no index, no end-to-end acceptance.
- **Depth beyond one level** (sub-issue of a sub-issue) — the parent's table is the only index; flatten.
- **One sub-issue spanning two repositories** (e.g. "implement the task *and* its UI window") — split by repository.
- **A parent that is only a list of links** — the parent must hold the shared spec, decisions and end-to-end acceptance.
- **A child that defers implementable detail to the parent** ("see parent for the exact names") — repeat the detail in the child.
- **Copying the parent's `ai:` tier / labels to the child** — tier each sub-issue from its own scope.
