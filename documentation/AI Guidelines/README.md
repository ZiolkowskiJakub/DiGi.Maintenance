# AI Guidelines — Index

The always-loaded entry point is `DigiProject/CLAUDE.md` (universal coding rules + a task→file
routing table). The files in this folder hold the full detail for specific tasks and are **read on
demand** — they are not auto-loaded, so open only the one that matches the task; reading an
irrelevant one just spends tokens.

## Coding
| File | Read it when… |
|------|---------------|
| [Coding - General.md](Coding%20-%20General.md) | Writing or modifying any C# — naming/typing rules, the DiGi.Core `Query`/`Modify`/`Create`/`Convert` architecture, and the `SerializableObject` serialization pattern (with worked examples). |
| [Coding - API Documentation.md](Coding%20-%20API%20Documentation.md) | Looking up a type's public API — consult the generated `documentation/API/` markdown before opening `.cs` source. |
| [Coding - Automatic Tests.md](Coding%20-%20Automatic%20Tests.md) | Writing or adding xUnit tests — `Facts` structure, naming, shared fixtures, and serialization/tolerance/performance patterns. |
| [Coding - WebAPI GLTF.md](Coding%20-%20WebAPI%20GLTF.md) | Building or extending an ASP.NET Core Web API on the `DiGi.GLTF` 3D framework — the decoupled pipeline, onboarding a new consuming project, adding a new 3D object type via the `IGLTFNodeConverter` registry, batching/streaming performance rules, and the `dotnet new` template. |

## XML documentation
| File | Read it when… |
|------|---------------|
| [XML Documentation - Create.md](XML%20Documentation%20-%20Create.md) | Adding missing `<summary>` docs to public members. |
| [XML Documentation - Audit.md](XML%20Documentation%20-%20Audit.md) | Auditing/synchronizing existing XML docs against current signatures (a superset of Create). |

## GitHub
| File | Read it when… |
|------|---------------|
| [GitHub - Branch Synchronization.md](GitHub%20-%20Branch%20Synchronization.md) | Running the version-branch → `main` merge + patch-bump release workflow. |
| [GitHub Wiki - General.md](GitHub%20Wiki%20-%20General.md) | Editing any GitHub wiki page — repo layout, local clones, CI sync mechanics. |
| [GitHub Wiki - Benchmark.md](GitHub%20Wiki%20-%20Benchmark.md) | Creating or updating a repo's `Benchmark` wiki page. |

---

**Not a guideline:** `compiled_guidelines.md` (in the `DigiProject` root) is a generated
concatenation consumed by `update_wikis_and_readmes.ps1` to sync per-repo READMEs and wiki
homepages. It is not an instruction file — never `@`-import it or load it into context.
