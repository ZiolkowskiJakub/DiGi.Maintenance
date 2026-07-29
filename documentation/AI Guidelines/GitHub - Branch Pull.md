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