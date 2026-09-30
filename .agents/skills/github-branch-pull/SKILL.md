---
name: github-branch-pull
description: "Use when scanning local DiGi repositories, identifying SemVer branches, selecting the highest version, and pulling/syncing the local machine with the latest remote state."
---

# AI Guidelines: Local Repository Pull & Synchronization

Automate scanning of local Git repositories, detection of highest SemVer release branches, and remote state synchronization.

---

## 1. Repository Discovery

- **Target Scope:** Scan local directories for Git repositories matching the "DiGi" naming convention.
- **Criteria:** Directory contains a `.git` folder and belongs to the DiGi project suite.

---

## 2. SemVer Branch Selection Logic

1. **Filter Version Branches:** Extract branches matching bare SemVer `*.*.*` (e.g., `0.8.4`, `0.8.5`). Ignore prefixes/suffixes (`main`, `v0.8.5`, `feature/*`).
2. **Select Highest Version:** Evaluate SemVer strings numerically. Select the highest available branch (e.g., select `0.8.5` over `0.8.4`).

---

## 3. Synchronization Pipeline

Execute sequentially per repository:

```bash
# 1. Fetch all remote branches and prune deleted tracking refs
git fetch --all --prune

# 2. Checkout the highest SemVer version branch
git checkout <highest_semver_branch>

# 3. Pull latest remote changes
git pull origin <highest_semver_branch>
```

---

## 4. Bulk Git Pull Timeout Guideline

A pull across every DiGi repository takes minutes, not seconds. Give the command a timeout of **at least
180 seconds** (e.g. `timeout: 180000` ms on an agent shell tool): a shorter one aborts partway through and
silently leaves the repositories later in alphabetical order (e.g. `DiGi.SAM`) un-pulled.

Prefer the script, which applies the §2 branch selection and needs no working directory — it resolves the
workspace root from its own location:

```powershell
PowerShell -ExecutionPolicy Bypass -File "DiGi.Maintenance/Scripts/PullBranchesAllRepos.ps1"
```

For a plain `git pull` of each repository's current branch, run from the workspace root (the folder that
holds the `DiGi.*` repositories). Limit the search depth so it does not descend into nested `.git` folders
inside a repository (vendored packages, virtual environments):

```bash
find . -mindepth 2 -maxdepth 2 -name ".git" -type d -exec sh -c 'cd "{}"/.. && pwd && git pull' \;
```
