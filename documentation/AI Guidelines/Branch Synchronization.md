# AI Orchestration Agent Guidelines: Branch Synchronization & Versioning

**Role:** You are an expert DevOps and C# Orchestration Agent managing Git workflows.  
**Task:** Automate branch synchronization, version bumping, and workspace context switching across project repositories.

---

## ⚠️ TRIGGER CONDITIONS (STRICT)
1. **Version Format:** Execute this workflow ONLY if the currently active branch follows the exact Semantic Versioning format of `*.*.*` (e.g., `0.8.2`, `1.12.0`). If the branch name contains text, prefixes, or suffixes (e.g., `feature/login`, `v0.8.2`, `0.8.2-beta`, `main`), DO NOT execute this protocol.
2. **Branch Differences:** Before selecting repositories to synchronize, compare the active branch with the `main` branch. Carry out the update process ONLY for repositories that have differences between the active branch and `main`. Skip any repository where the active branch and `main` are identical.

---

## 🔄 SYNCHRONIZATION WORKFLOW (EXECUTION STEPS)

If the trigger conditions are met, perform the following steps sequentially for the applicable repositories:

1. **Synchronize with Main:** Synchronize the active version branch with the `main` branch so that both branches contain the exact same codebase. This typically involves merging the current version branch into `main` and ensuring no pending diffs remain.
2. **Calculate Next Version (Patch Bump):** Increment the third digit (patch version) of the current branch name by exactly `1`. 
   *Example:* If the current active branch is `0.8.2`, the target version becomes `0.8.3`.
3. **Create New Branch:** Create a new branch off `main` using the target version name calculated in Step 2.
4. **Update Version in Directory.Build.props:** If a `Directory.Build.props` file exists in the repository, update the `<Major>`, `<Minor>`, and `<Build>` XML tags to match the components of the new branch version (e.g., for branch `0.8.1`, set `<Major>0</Major>`, `<Minor>8</Minor>`, `<Build>1</Build>`). Commit this change on the new branch before pushing.
5. **Publish to GitHub & Set Upstream:** Push both the updated `main` branch and the newly created version branch to the remote repository on GitHub (origin). Use the `--set-upstream` (or `-u`) flag when pushing the new version branch so that it tracks properly and displays standard synchronization options in GitHub Desktop (e.g., `git push -u origin <version_branch>`).