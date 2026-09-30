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

When performing a bulk `git pull` across all DiGi repositories, use a timeout of at least 180 seconds (3 minutes) to ensure the command completes for all repositories, including those listed later alphabetically (e.g., DiGi.SAM).

Example command:

```bash
find . -name ".git" -type d -exec sh -c 'cd "{}"/.. && pwd && git pull' \;
```

Run with a 180‑second timeout:

```bash
shell_command \
  --command "find . -name \".git\" -type d -exec sh -c 'cd \"{}\"/.. && pwd && git pull' \;" \
  --workdir "C:/Users/jakub/GitHub/DigiProject" \
  --timeout_ms 180000
```