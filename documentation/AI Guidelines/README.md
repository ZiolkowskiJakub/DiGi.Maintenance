# AI Guidelines — Index

> [!IMPORTANT]
> **Portability Rule:** All markdown files in this repository (such as guidelines, READMEs, CLAUDE.md, etc.) must use **relative paths** for file references and links. Do not include any machine-specific or absolute user paths (like `C:\Users\...`) to ensure the files remain portable across different systems and prevent leaking user-specific configuration data.

The always-loaded entry point is `DigiProject/CLAUDE.md` (universal coding rules + a task→file
routing table). The files in this folder hold the full detail for specific tasks and are **read on
demand** — they are not auto-loaded, so open only the one that matches the task; reading an
irrelevant one just spends tokens.

## General AI Priorities

Unless explicitly instructed otherwise in the prompt, the AI must strictly adhere to the following hierarchy of priorities when operating on this codebase:

1. **Quality & Guideline Adherence (Highest Priority):** Code correctness, architectural soundness, and strict compliance with the established guidelines (e.g., explicit typing, DI patterns, English-only code) are absolute. Never compromise on the rules.
2. **Output Optimization & Token Efficiency (High Priority):** Prioritize highest code quality and output token minimization. Skip conversational filler, polite introductions, and conclusions. Output only the necessary code, logic, or requested explanations. Do not read irrelevant guideline markdown files.
3. **Speed (Lowest Priority):** The speed of generating a response is not important. It can, and should, be sacrificed to ensure maximum quality, deep reasoning, and efficient token usage. 

Additionally:
* **Project Structure:** Assume the C# codebase consists of multiple SEPARATE projects, not a single monolithic solution. Handle namespaces and references accordingly.


## Coding
| File | Read it when… |
|------|---------------|
| [Coding - General.md](Coding%20-%20General.md) | Writing or modifying any C# — naming/typing rules, the DiGi.Core `Query`/`Modify`/`Create`/`Convert` architecture, and the `SerializableObject` serialization pattern (with worked examples). |
| [Coding - API Documentation.md](Coding%20-%20API%20Documentation.md) | Looking up a type's public API — consult the generated `documentation/API/` markdown before opening `.cs` source. |
| [Coding - References.md](Coding%20-%20References.md) | Comparing, matching, keying or de-duplicating an `IReference`/`IUniqueReference` — why `==` between two interface-typed references is a silent bug, what to use instead, and how to detect and fix existing occurrences. |
| [Coding - Automatic Tests.md](Coding%20-%20Automatic%20Tests.md) | Writing or adding xUnit tests — `Facts` structure, naming, shared fixtures, and serialization/tolerance/performance patterns. |
| [Coding - Templates.md](Coding%20-%20Templates.md) | Creating a new project/solution from a template, or adding/modifying templates in the workspace's default `templates/` folder. |
| [Coding - WebAPI GLTF.md](Coding%20-%20WebAPI%20GLTF.md) | Building or extending an ASP.NET Core Web API on the `DiGi.GLTF` 3D framework — the decoupled pipeline, onboarding a new consuming project, adding a new 3D object type via the `IGLTFNodeConverter` registry, and batching/streaming performance rules. |
| [Coding - Deployed WebAPI.md](Coding%20-%20Deployed%20WebAPI.md) | Verifying a client/server change against the live WebAPI at `api.digiproject.uk` — swagger source of truth, the county→reference→building GET test recipe, access rules and gotchas. Manual `curl` checks only, never added to `DiGi.Test`. |

## XML documentation
| File | Read it when… |
|------|---------------|
| [XML Documentation - Create.md](XML%20Documentation%20-%20Create.md) | Adding missing `<summary>` docs to public members. |
| [XML Documentation - Audit.md](XML%20Documentation%20-%20Audit.md) | Auditing/synchronizing existing XML docs against current signatures (a superset of Create). |

## GitHub
| File | Read it when… |
|------|---------------|
| [GitHub - Branch Pull.md](GitHub%20-%20Branch%20Pull.md) | Scanning local DiGi repositories, selecting the highest SemVer branch, and pulling/syncing the local machine with the latest remote state. |
| [GitHub - Branch Synchronization.md](GitHub%20-%20Branch%20Synchronization.md) | Running the version-branch → `main` merge + patch-bump release workflow. |
| [GitHub Wiki - General.md](GitHub%20Wiki%20-%20General.md) | Editing any GitHub wiki page — repo layout, local clones, CI sync mechanics. |
| [GitHub Wiki - Home.md](GitHub%20Wiki%20-%20Home.md) | Creating or editing a repository's Wiki Home page structure. |
| [GitHub Wiki - Benchmark.md](GitHub%20Wiki%20-%20Benchmark.md) | Creating or updating a repo's `Benchmark` wiki page. |

---

## How these files are propagated

Everything below is generated from this folder — edit the guideline here, never the generated copy:

| Generated output | Produced by | Contents |
|------------------|-------------|----------|
| `<repo>/.agents/AGENTS.md` + `<repo>/.agents/skills/*/SKILL.md` in every `DiGi.*` repo | `DiGi.Maintenance/Scripts/UpdateAgents.ps1` | A copy of `DiGi.Maintenance/.agents/AGENTS.md`, plus one skill per guideline file in this folder (`README.md` excluded). The skill folder name is the file name lower-cased with separators collapsed to `-` (`Coding - Deployed WebAPI.md` → `coding-deployed-webapi`); its frontmatter `description` comes from the `$descriptions` table in that script, so **a new guideline file needs a matching entry there**. |
| The `## 💻 Coding Guidelines for Developers & AI Agents` block at the end of every `DiGi.*/README.md` | `DiGi.Maintenance/Scripts/UpdateReadmes.ps1` | The canonical block in `DiGi.Maintenance/files/README - Coding Guidelines.md` — a condensed, reader-facing digest of the coding guidelines. It is maintained by hand and must be updated when a guideline above changes materially. Everything above the marker heading in a repo's `README.md` is repository-specific and is preserved. |
| A machine-global `AGENTS.md` outside the workspace (optional) | `DiGi.Maintenance/Scripts/UpdateAgents.ps1` | The concatenation of every guideline in this folder, appended after the file's `## Summary of Core Coding & Testing Guidelines` heading. The target path is read from `GLOBAL_AGENTS_FILE` in `DiGi.Maintenance/user files/Directories.conf`; when unset, the step is skipped. |

Run both after changing anything in this folder:

```powershell
PowerShell -ExecutionPolicy Bypass -File ".\UpdateAgents.ps1"
PowerShell -ExecutionPolicy Bypass -File ".\UpdateReadmes.ps1"
```