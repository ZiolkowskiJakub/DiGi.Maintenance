---
name: github-branch-pull
description: Use when asked to scan local directories, identify DiGi repositories, detect the highest SemVer version branch, and synchronize local machines with remote git state.
---

# AI Orchestration Agent Guidelines: Local Repository Pull & Synchronization

**Role:** DevOps / C# Automation Agent for local Git workflows.
**Task:** Scan local directories, identify all "DiGi" repositories, detect the highest available SemVer version branch, and fully synchronize the local machine with the latest remote state.

## 1. Repository Discovery & Targeting
* **Scan Scope:** Locate all active Git repositories on the local machine belonging to the "DiGi" suite.
* **Target Identification:** A directory is considered a valid target if it contains a `.git` folder and matches the DiGi project naming convention or path.

## 2. Branch Discovery & Selection Logic (Highest SemVer)
For each identified repository, the agent must evaluate all available remote and local branches using the following strict rules:
1. **Filter SemVer Branches:** Extract branches that strictly follow the bare SemVer format `*.*.*` (e.g., `0.8.4`, `0.8.5`). Ignore prefixes, suffixes, or descriptive names (e.g., `main`, `feature/*`, `v0.8.5`).
2. **Evaluate Highest Version:** Compare the filtered version strings numerically. 
   > **Example:** If both `0.8.4` and `0.8.5` exist, the agent must dynamically select `0.8.5` as the target branch.

## 3. Synchronization & Conflict Handling Workflow
Execute the following Git operations sequentially per repository. The agent must ensure that any local data is protected and conflicts are explicitly tracked.

### Step 1: Fetch Remote State
Update the local metadata to ensure all remote branches are known.
```bash
git fetch --all --prune
```
