---
name: github-ai-issue-classification
description: Use when assigning the mandatory 'ai: *' complexity tier to a GitHub issue - the four tiers (light, standard, heavy, ultra), the criteria and capability band of each, and the decision procedure (estimate files touched and depth of architectural understanding, and err to the higher tier when core abstractions or core business logic are involved).
---

# AI Guidelines: AI Issue Classification

Guidelines for assigning the `ai: *` complexity tier, which records how much AI capability a GitHub issue needs in order to be resolved. The tier travels with the issue as a routing decision, alongside its `type: *` and `priority: *` labels.

---

## 1. Scope

When generating or analyzing a GitHub issue, you **must** assign exactly one `ai: *` label indicating the computational complexity and the level of AI reasoning required to resolve the task. This is the third mandatory dimension: every new issue carries one `type: *`, one `priority: *`, and one `ai: *` label at creation time (see `GitHub - Labels.md` §2 and `GitHub - Issues.md` §1).

Pull requests are out of scope - they carry a `type: *` label only.

| Label | Complexity | Capability band |
| :--- | :--- | :--- |
| `ai: light` | Trivial | Small local model, under 14B parameters |
| `ai: standard` | Narrow scope, real logic | Large local model on workstation-class GPU hardware, roughly 31B-70B parameters |
| `ai: heavy` | Broad repository context | Frontier cloud model |
| `ai: ultra` | Architectural / algorithmic | Top-tier extended-reasoning model, combined with human oversight |

Capability bands are stated as capabilities rather than product names deliberately - named models turn over faster than this guideline does.

---

## 2. Tier Criteria

### A. `ai: light`

Assign this label for trivial tasks that require minimal context and reasoning.

- Fixing typos, updating documentation, or adding simple code comments.
- Generating standard boilerplate code (e.g. standard DTOs, basic interface implementations).
- Isolated, single-line or localized bug fixes with obvious solutions.

**Capability band:** small, fast local models (under 14B parameters).

### B. `ai: standard`

Assign this label for standard development tasks that are contained within a narrow scope but require actual programming logic.

- Implementing a single method or feature entirely contained within 1 or 2 files.
- Writing standard unit tests (e.g. xUnit tests with Moq/NSubstitute for an existing class).
- Moderate refactoring that does not break external contracts (e.g. simplifying LINQ queries, applying C# 13+ features to existing methods).

**Capability band:** large local models running on heavy hardware (roughly 31B-70B parameter models on a workstation-class GPU).

### C. `ai: heavy`

Assign this label for complex tasks requiring broad repository context and structural awareness.

- Multi-file refactoring that impacts several layers of the application (e.g. changing a database schema and updating the corresponding data-access models and API endpoints).
- Debugging complex, multi-threaded issues or asynchronous deadlocks.
- Implementing cross-cutting concerns like custom authentication handlers or complex middleware.

**Capability band:** standard frontier cloud models.

### D. `ai: ultra`

Assign this label for extreme complexity, architectural design, or tasks requiring deep algorithmic deduction.

- Designing completely new system architectures or heavy database migration strategies.
- Solving deeply nested performance bottlenecks or memory leak profiling.
- Tasks requiring heavy domain knowledge, high abstraction, or integration with undocumented third-party systems.

**Capability band:** the most powerful reasoning models available (extended thinking / deep reasoning), combined with human oversight.

---

## 3. Decision Procedure

Evaluate the task scope. Calculate the number of files likely to be modified and the depth of architectural understanding required. **Always err on the side of a higher tier if the task involves modifying core abstractions or core business logic.** When asked only to classify, output ONLY the most appropriate `ai:` label.

Practical signals in this workspace:

| Signal | Tier pull |
| :--- | :--- |
| XML docs, wiki pages, guideline text, a `TODO [Marker]` checklist | `ai: light` |
| One `Query`/`Modify`/`Create`/`Convert` member and its `[Fact]` | `ai: standard` |
| A change spanning a converter, its controller, and an HTTP client | `ai: heavy` |
| Geometry/algorithmic correctness, allocation profiling, cross-repository schema or reference-format migrations | `ai: ultra` |

The existing `type: *` label is a hint, not the answer: `type: documentation` usually means `ai: light`, but a temporary-code removal checklist spanning four live markers does not. Decide from the issue body.

---

## 4. Application

1. **Exactly one** `ai: *` label per issue - the tiers are mutually exclusive.
2. Assign it at creation time, in the same `--label` argument as the type and priority (`GitHub - Issues.md` §1).
3. Re-tier an existing issue when its scope is understood to be materially different from what the title implied; remove the old tier in the same `gh issue edit` call.
4. The four labels are created and kept in sync across repositories by `SyncLabelsAllRepos.ps1` - see `GitHub - Labels.md` §3.
