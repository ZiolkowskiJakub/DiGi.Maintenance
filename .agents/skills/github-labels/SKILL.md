---
name: github-labels
description: Use when standardizing, applying, or syncing GitHub issue and PR labels across repositories - Type, Priority, and Status taxonomy, requiring Type and Priority on every new issue, and updating labels only on open issues by default.
---

# AI Guidelines: GitHub Labels

Guidelines for standardizing, applying, and managing labels on GitHub issues and pull requests across all DiGi repositories.

---

## 1. Taxonomy & Color Standards

Every DiGi repository adheres to a uniform label taxonomy categorized into **Type**, **Priority**, and **Status**. Standardizing prefixes (`type:`, `priority:`, `status:`) ensures clean organization, auto-complete efficiency in GitHub, and clear visual triage.

### A. Type Labels (`type: *`) — *What is being changed?*

| Label | Color | Description |
| :--- | :--- | :--- |
| `type: bug` | `#d73a4a` | Confirmed defect or regression in logic, data handling, or output |
| `type: feature` | `#0e8a16` | Substantial new functionality or public API capability |
| `type: enhancement` | `#a2eeef` | Improvement, optimization, or refinement of an existing capability |
| `type: performance` | `#1d76db` | Execution speedup, memory allocation reduction, or query tuning |
| `type: refactor` | `#6f42c1` | Architectural or structural code cleanup with no behavioral change |
| `type: breaking-change` | `#b60205` | Breaking API change requiring major/minor version increments |
| `type: documentation` | `#0075ca` | XML documentation, AI guidelines, or GitHub wiki updates |
| `type: test` | `#fbca04` | Test facts in `DiGi.Test`, benchmarks, or test fixtures |
| `type: maintenance` | `#d4c5f9` | CI/CD, project dependencies, `.editorconfig`, or build script updates |

### B. Priority Labels (`priority: *`) — *How critical / urgent is it?*

| Label | Color | Description |
| :--- | :--- | :--- |
| `priority: critical` | `#b60205` | Blocks deployment, corrupts data, or causes service outage |
| `priority: high` | `#d93f0b` | Severe bug or major blocker for current release milestone |
| `priority: medium` | `#fb8c00` | Normal priority; addressed in standard development cycle |
| `priority: low` | `#e0e0e0` | Minor inconvenience, cosmetic, or low-impact task |

### C. Status Labels (`status: *`) — *Where is it in the workflow?*

| Label | Color | Description |
| :--- | :--- | :--- |
| `status: in-progress` | `#0e8a16` | Active work is underway |
| `status: blocked` | `#b60205` | Blocked by upstream dependency or external issue |
| `status: needs-review` | `#fb8c00` | Implementation ready for verification or code review |

---

## 2. Labeling Rules for Issues & Pull Requests

1. **Mandatory Type & Priority on Creation:** Every new issue created in any repository **must** have at least one `type: *` label and one `priority: *` label assigned at creation time (e.g. `type: bug`, `priority: high`).
2. **Pull Requests:** Every pull request must have at least one `type: *` label matching the nature of the change.
3. **Workflow State:** Use `status: *` labels when an issue is blocked by an external component or actively pending code review. Remove status labels once resolved.
4. **No Legacy or Ad-hoc Labels:** Avoid creating custom un-prefixed labels (e.g. bare `bug`, `enhancement`, `help wanted`, `wontfix`). All repositories maintain this exact 16-label standard.
5. **GitHub Label Synchronization Scope:**
   - **Default Behavior:** Update labels **ONLY on open issues**.
   - **Exception:** Modify labels on closed issues **ONLY if explicitly instructed by the user**.

---

## 3. Synchronization & Automation

The repository label taxonomy is managed and synced across all DiGi repositories using the maintenance script:

```powershell
# Preview label changes across all repositories
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/SyncLabelsAllRepos.ps1" -DryRun

# Sync labels for a single target repository
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/SyncLabelsAllRepos.ps1" -Repo "DiGi.Core"

# Sync labels across all DiGi repositories
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/SyncLabelsAllRepos.ps1"
```

The script:
1. Creates missing standard labels with exact names, colors, and descriptions.
2. Updates existing labels if colors or descriptions differ.
3. Migrates issues using legacy labels (`bug` -> `type: bug`, `enhancement` -> `type: enhancement`, `documentation` -> `type: documentation`).
4. Deletes obsolete default GitHub labels (`good first issue`, `help wanted`, `invalid`, `question`, `wontfix`, `duplicate`).
