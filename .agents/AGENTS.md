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
- **coding-general:** Use whenever writing or editing C# code — naming/typing rules, the DiGi.Core `Query`/`Modify`/`Create`/`Convert` architecture, files vs user files assets, and the `SerializableObject` serialization pattern.
- **coding-api-documentation:** Use when looking up a type's public API — consult the generated `documentation/API/` markdown before opening `.cs` source.
- **coding-references:** Use when comparing, matching, keying or de-duplicating an `IReference`/`IUniqueReference` — why `==` between two interface-typed references is a silent bug, what to use instead, and how to detect and fix existing occurrences.
- **coding-automatic-tests:** Use when writing or adding xUnit tests — `Facts` structure, naming, shared fixtures, serialization, tolerance boundary, and performance benchmarks.
- **coding-templates:** Use when creating a new project/solution from a template, or managing templates in the workspace's default `templates/` folder.
- **coding-webapi-gltf:** Use when building or extending an ASP.NET Core Web API on the `DiGi.GLTF` 3D framework.
- **coding-deployed-webapi:** Use when verifying a client/server change against the live WebAPI at `api.digiproject.uk` — swagger as the source of truth, the county→reference→building GET test recipe, access rules and gotchas. Manual `curl` checks only, never added to `DiGi.Test`.

### XML Documentation
- **xml-documentation-create:** Use when adding missing `<summary>` docs to public members.
- **xml-documentation-audit:** Use when auditing/synchronizing existing XML docs against current signatures.

### GitHub
- **github-branch-pull:** Use when scanning local repositories, identifying SemVer branches, finding the highest version, and pulling remote branches.
- **github-branch-synchronization:** Use when synchronizing version branch to `main`, bump patch version, creating a new branch, and updating `Directory.Build.props`.

### GitHub Wiki
- **github-wiki-general:** Use when editing any GitHub wiki page — repo layout, local clones, CI sync mechanics.
- **github-wiki-home:** Use when creating or editing a repository's Wiki Home page template.
- **github-wiki-benchmark:** Use when creating or updating a repo's `Benchmark` wiki page.
