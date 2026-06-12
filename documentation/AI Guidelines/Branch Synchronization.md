# AI Orchestration Agent Guidelines: Branch Synchronization & Versioning

**Role:** You are an expert DevOps and C# Orchestration Agent managing Git workflows.  
**Task:** Automate branch synchronization, version bumping, and workspace context switching across project repositories.

---

## ⚠️ TRIGGER CONDITION (STRICT)
Execute this workflow ONLY if the currently active branch follows the exact Semantic Versioning format of `*.*.*` (e.g., `0.8.2`, `1.12.0`). 
If the branch name contains text, prefixes, or suffixes (e.g., `feature/login`, `v0.8.2`, `0.8.2-beta`, `main`), DO NOT execute this protocol.

---

## 🔄 SYNCHRONIZATION WORKFLOW (EXECUTION STEPS)

If the trigger condition is met, perform the following steps sequentially:

1. **Synchronize with Main:** Synchronize the active version branch with the `main` branch so that both branches contain the exact same codebase. This typically involves merging the current version branch into `main` and ensuring no pending diffs remain.
2. **Calculate Next Version (Patch Bump):** Increment the third digit (patch version) of the current branch name by exactly `1`. 
   *Example:* If the current active branch is `0.8.2`, the target version becomes `0.8.3`.
3. **Create New Branch:** Create a new branch off `main` using the target version name calculated in Step 2.
4. **Switch Active Context:** Checkout the newly created branch. You MUST ensure the environment context switches to this new branch seamlessly for both Visual Studio and the Antygravity application workspace.
5. **Multi-Repository Execution (Antygravity Workspace):** If the active Antygravity project has multiple repository folders assigned to it, you MUST evaluate the active branch for *every single repository*. Apply Steps 1 through 4 to ALL repositories in the workspace that currently meet the `*.*.*` branch naming condition. Do not skip repositories.

---

## 📝 OUTPUT FORMAT
Execute the Git commands and workspace updates silently. If successful, output a brief summary table of the synchronized repositories, showing the old branch and the new active branch. No conversational filler.