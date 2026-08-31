# AI General Rules & Priorities

> [!IMPORTANT]
> **Portability Rule:** All markdown files in this repository (such as guidelines, READMEs, CLAUDE.md, etc.) must use **relative paths** for file references and links. Do not include any machine-specific or absolute user paths (like `C:\Users\...`) to ensure the files remain portable across different systems and prevent leaking user-specific configuration data.

## General AI Priorities

Unless explicitly instructed otherwise in the prompt, the AI must strictly adhere to the following hierarchy of priorities when operating on this codebase:

1. **Quality & Guideline Adherence (Highest Priority):** Code correctness, architectural soundness, and strict compliance with the established guidelines (e.g., explicit typing, DI patterns, English-only code) are absolute. Never compromise on the rules.
2. **Output Optimization & Token Efficiency (High Priority):** Prioritize highest code quality and output token minimization. Skip conversational filler, polite introductions, and conclusions. Output only the necessary code, logic, or requested explanations. Do not read irrelevant guideline markdown files.
3. **Speed (Lowest Priority):** The speed of generating a response is not important. It can, and should, be sacrificed to ensure maximum quality, deep reasoning, and efficient token usage.

Additionally:
* **Project Structure:** Assume the C# codebase consists of multiple SEPARATE projects, not a single monolithic solution. Handle namespaces and references accordingly.

---

## Guidelines Index & Task Routing

The files in the `skills/` directory hold the full details for specific tasks and are activated on demand. Consult the matching skill when performing these tasks:

### Coding
- **coding-general:** Use whenever writing or editing C# code — naming/typing rules, the DiGi.Core `Query`/`Modify`/`Create`/`Convert` architecture, cheap constructors with the work in a `Create` factory, one-member-per-file layout, files vs user files assets, the `SerializableObject` serialization pattern, and the host `PackageReference` rules for NuGet dependencies a `HintPath` reference drops.
- **coding-editor-config:** Use when configuring, auditing or enforcing `.editorconfig` code style — explicit typing (no `var`), block-scoped namespaces, collection expressions `[]`, target-typed `new()`, member-body discipline, and the diagnostic severity overrides.
- **coding-api-documentation:** Use when looking up a type's public API — consult the generated `documentation/API/` markdown before opening `.cs` source.
- **coding-references:** Use when comparing, matching, keying or de-duplicating an `IReference`/`IUniqueReference` — why `==` between two interface-typed references is a silent bug, what to use instead, and how to detect and fix existing occurrences.
- **coding-automatic-tests:** Use when writing or adding xUnit tests — `Facts` structure, naming, shared fixtures, serialization, tolerance boundary, and performance benchmarks.
- **coding-templates:** Use when creating a new project/solution from a template, or managing templates in the workspace's default `templates/` folder.
- **coding-webapi-gltf:** Use when building or extending an ASP.NET Core Web API on the `DiGi.GLTF` 3D framework.
- **coding-webapi-contracts:** Use when changing a WebAPI controller's route, parameter names or validation, or when writing/maintaining an HTTP client of one — why a renamed parameter breaks clients with no compile or runtime error, the query-binding traps (an omitted parameter keeps `default(T)`, an enum sentinel that is not `0`), sending enums as integers, the client `/Query` plumbing pattern, and gating an endpoint that is not deployed yet.
- **coding-webapi-simple-authorization:** Use when implementing or auditing lightweight API-key-based tiered authorization for WebAPI controllers — deny-by-default `IsAuthorized`, `[Feature]Configuration` model with an `Open` escape hatch, `files/*.conf` committed defaults vs `user files/` secrets, `[FromHeader(Name = "key")]` binding, constant-time key comparison, singleton registration on the host, MSBuild copy targets, and `SyncDirectories.ps1` deployment synchronization.
- **coding-deployed-webapi:** Use when verifying a client/server change against the live WebAPI at `api.digiproject.uk` — swagger as the source of truth, the deployed build lagging the repository, the county→reference→building GET test recipe, access rules and gotchas. Manual `curl` checks only, never added to `DiGi.Test`.
- **coding-gis-administrative-data:** Use when touching `administrative_areal_2d`, `building_2d`, or anything keyed by a county code or id — why a county code is not a key (one row per polygon part of a multi-part county), the BDOT10k source layout, the `building_2d` duplicates, and the ordering rules that keep resolution deterministic.
- **coding-postgresql:** Use when designing schemas or writing queries with Npgsql / PostgreSQL — `Classes/Converter/` layout, `NULLS NOT DISTINCT` composite unique indexes for nullable columns, query batching (`batchSize = 1000`, `ANY(@array)`), `commandTimeout` parameter standard, and connection asset isolation in `user files/`.
- **coding-postgresql-distributed-queue-processing:** Use when designing or maintaining distributed bulk update queues in PostgreSQL — table schema (`claimed_at`, `created_at`, natural uniqueness), atomic lease claims with `FOR UPDATE SKIP LOCKED`, native interval arithmetic (`@minutes * interval '1 minute'`), explicit batch acknowledgment (`DELETE ... WHERE id = ANY(@ids)`), crash recovery, and non-destructive queue observation.

### XML Documentation
- **xml-documentation-create:** Use when adding missing `<summary>` docs to public members.
- **xml-documentation-audit:** Use when auditing/synchronizing existing XML docs against current signatures.

### GitHub
- **github-branch-pull:** Use when scanning local repositories, identifying SemVer branches, finding the highest version, and pulling remote branches.
- **github-branch-synchronization:** Use when synchronizing version branch to `main`, bump patch version, creating a new branch, and updating `Directory.Build.props`.
- **github-issues:** Use when querying, filtering, creating, managing, commenting on, or closing GitHub issues/PRs — filtering issues by labels via FilterIssues.ps1 to reduce token usage, verifying an issue's stated premises against the code before implementing it (does the missing optimization already exist, is the quoted latency reproducible, does the failure reproduce) and correcting the record when a claim is wrong, mandatory Type, Priority and AI Complexity labels on all new issues, and mandatory --body-file usage to avoid PowerShell escape mangling.
- **github-labels:** Use when standardizing, applying, or syncing GitHub issue and PR labels across repositories — Type, Priority, Status and AI Complexity taxonomy, requiring Type, Priority and an `ai: *` tier on every new issue, and updating labels only on open issues by default.
- **github-ai-issue-classification:** Use when assigning the mandatory `ai: *` complexity tier to an issue — the four tiers (light, standard, heavy, ultra), their criteria and capability bands, and the decision procedure (err to the higher tier when core abstractions or core business logic are involved).

### GitHub Wiki
- **github-wiki-general:** Use when editing any GitHub wiki page — repo layout, local clones, CI sync mechanics.
- **github-wiki-home:** Use when creating or editing a repository's Wiki Home page template.
- **github-wiki-benchmark:** Use when creating or updating a repo's `Benchmark` wiki page.
