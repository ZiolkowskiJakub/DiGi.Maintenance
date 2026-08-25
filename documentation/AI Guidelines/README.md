# AI Guidelines — Index

> [!IMPORTANT]
> **Portability Rule:** All markdown files must use **relative paths** for file references. Do not include absolute machine paths (e.g. `C:\Users\...`).

Entry point: `DigiProject/CLAUDE.md` (universal coding rules + routing table). The files in this directory contain detailed task instructions and must be **read on demand**.

## Priorities

1. **Quality & Compliance (Highest):** Strict adherence to code correctness, architecture, explicit typing, DI patterns, and English-only code.
2. **Output & Token Efficiency (High):** Minimize token usage. Omit conversational filler, polite text, and irrelevant file reads.
3. **Speed (Lowest):** Sacrifice speed for quality, deep reasoning, and token efficiency.
4. **Project Structure:** Treat C# codebase as multiple SEPARATE projects, not a monolith.

## Routing Table

### Coding
| File | Trigger Task |
|------|--------------|
| [Coding - General.md](Coding%20-%20General.md) | C# coding, naming/typing rules, `Query`/`Modify`/`Create`/`Convert` architecture, `SerializableObject` pattern, checking an already-referenced package before adding a NuGet one, host `PackageReference` rules for `HintPath`-dropped NuGet dependencies, `TODO [Marker]` temporary-code tags. |
| [Coding - Editor Config.md](Coding%20-%20Editor%20Config.md) | `.editorconfig` rules, explicit typing (`no var`), block namespaces, collection expressions (`[]`), `new()`. |
| [Coding - API Documentation.md](Coding%20-%20API%20Documentation.md) | Public API lookup — consult `documentation/API/` before `.cs` source. |
| [Coding - References.md](Coding%20-%20References.md) | `IReference`/`IUniqueReference` comparison — prohibit `==`/`!=` on interface references, use `Core.Query.Equals`. |
| [Coding - Automatic Tests.md](Coding%20-%20Automatic%20Tests.md) | xUnit testing — `Facts` structure, shared fixtures (`DiGi.Test/files/`), serialization/tolerance/performance tests, benchmark isolation, reproduce-before-fixing. |
| [Coding - Templates.md](Coding%20-%20Templates.md) | Solution/project scaffolding via `templates/` folder (`DiGi.Template`, `DiGi.WebAPI.GLTF.Template`). |
| [Coding - WebAPI GLTF.md](Coding%20-%20WebAPI%20GLTF.md) | `DiGi.GLTF` 3D Web API — 4-step pipeline, `IGLTFNodeConverter` registry, batching (`batched: true`), streaming. |
| [Coding - WebAPI Contracts.md](Coding%20-%20WebAPI%20Contracts.md) | Changing a WebAPI route/parameter, or writing an HTTP client of one — silent contract drift, query-binding traps (omitted parameters, enum sentinels), client `/Query` plumbing, gating undeployed endpoints. |
| [Coding - Deployed WebAPI.md](Coding%20-%20Deployed%20WebAPI.md) | Live WebAPI testing at `api.digiproject.uk` — swagger caveats, deployed-build lag, GET test recipe (`countyid` required), gotchas. |
| [Coding - GIS Administrative Data.md](Coding%20-%20GIS%20Administrative%20Data.md) | `administrative_areal_2d` storage — multi-part counties (one row per polygon part), why county `code` is not a key, `building_2d` duplicates, BDOT10k source layout. |
| [Coding - PostgreSQL.md](Coding%20-%20PostgreSQL.md) | PostgreSQL / Npgsql database engineering — `Classes/Converter/` architecture, `NULLS NOT DISTINCT` unique index syntax, query batching (`batchSize = 1000`, `ANY(@array)`), `commandTimeout` parameter standard, connection asset isolation in `user files/`. |

### XML Documentation
| File | Trigger Task |
|------|--------------|
| [XML Documentation - Create.md](XML%20Documentation%20-%20Create.md) | Adding missing `<summary>` documentation to public members. |
| [XML Documentation - Audit.md](XML%20Documentation%20-%20Audit.md) | Auditing and synchronizing XML docs against code signatures. |

### GitHub & Wiki
| File | Trigger Task |
|------|--------------|
| [GitHub - Branch Pull.md](GitHub%20-%20Branch%20Pull.md) | Local repo scanning, highest SemVer branch selection, git remote fetch/sync. |
| [GitHub - Branch Synchronization.md](GitHub%20-%20Branch%20Synchronization.md) | Version branch sync with `main`, patch version bump workflow. |
| [GitHub - Issues.md](GitHub%20-%20Issues.md) | Managing, commenting on, and closing GitHub issues/PRs — verifying an issue's premises before implementing it, mandatory Type and Priority labels on new issues, and `--body-file` usage to avoid PowerShell escape mangling. |
| [GitHub - Labels.md](GitHub%20-%20Labels.md) | Standardized GitHub label taxonomy (type, priority, status), color standard, mandatory Type + Priority on new issues, and multi-repo sync. |
| [GitHub Wiki - General.md](GitHub%20Wiki%20-%20General.md) | Editing GitHub wiki pages — repo structure, local clones, CI sync. |
| [GitHub Wiki - Home.md](GitHub%20Wiki%20-%20Home.md) | Structuring/updating wiki `Home.md` landing page. |
| [GitHub Wiki - Benchmark.md](GitHub%20Wiki%20-%20Benchmark.md) | Authoring/updating wiki `Benchmark.md` performance pages. |

---

## Guideline Propagation

Edit source files in this folder only. Generated downstream outputs:

| Target | Script | Description |
|--------|--------|-------------|
| `<repo>/.agents/skills/*/SKILL.md` | `DiGi.Maintenance/Scripts/UpdateAgents.ps1` | Copies `.agents/AGENTS.md` and generates one skill per guideline file (lowercased with hyphen separators). |
| `DiGi.*/README.md` | `DiGi.Maintenance/Scripts/UpdateReadmes.ps1` | Updates `## 💻 Coding Guidelines` block from `DiGi.Maintenance/files/README - Coding Guidelines.md`. |
| Machine `AGENTS.md` | `DiGi.Maintenance/Scripts/UpdateAgents.ps1` | Concatenates all guidelines if `GLOBAL_AGENTS_FILE` is configured. |

### Hand-synced inputs — the scripts do not derive these from the guideline files

A new or changed rule stops at the source unless these are updated by hand as well:

| File | What it carries |
|------|-----------------|
| `DiGi.Maintenance/files/README - Coding Guidelines.md` | The README block. A condensed parallel document, **not** a concatenation — new rules must be written into it. Its first line must stay the `## 💻 Coding Guidelines…` marker (`UpdateReadmes.ps1` hard-fails otherwise). |
| `DiGi.Maintenance/.agents/AGENTS.md` | The skill routing list. |
| `$descriptions` in `UpdateAgents.ps1` | The `description:` frontmatter of each generated `SKILL.md`, keyed by skill name. A missing key only warns and falls back to `"Use for tasks related to <skill-name>."`, so a new guideline ships to every repo with a useless description. |
| `DigiProject/CLAUDE.md` | The Claude Code condensation (re-sync it whenever it disagrees with this folder). |

Run scripts after changing guidelines:
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\UpdateAgents.ps1" -NoCommit
PowerShell -ExecutionPolicy Bypass -File ".\UpdateReadmes.ps1" -NoCommit
```
Both scripts walk **every** `DiGi.*` repository and **commit in each one** — drop `-NoCommit` only when
a commit per repository is actually wanted.