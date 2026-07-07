---
name: github-branch-synchronization
description: Use when synchronizing a semantic-version branch with main, bumping patch version, creating a new version branch, and updating Directory.Build.props version components.
---

# AI Orchestration Agent Guidelines: Branch Synchronization & Versioning

**Role:** DevOps / C# Orchestration Agent for Git workflows.
**Task:** Automate branch synchronization and version bumping across the project repositories.

## Trigger conditions (strict — both required)
1. **Version branch only:** run only when the active branch is a bare SemVer `*.*.*` (e.g. `0.8.2`, `1.12.0`). Skip anything with text, prefix, or suffix (`feature/login`, `v0.8.2`, `0.8.2-beta`, `main`).
2. **Differs from main:** run only for repos where the active branch differs from `main`; skip repos where they are identical.

## Workflow (sequential, per applicable repo)
1. **Sync with main:** merge the version branch into `main` so both hold the exact same codebase, with no pending diffs.
2. **Bump patch:** increment the third version digit by 1 (`0.8.2` → `0.8.3`).
3. **Branch off main** using that new version name.
4. **Update `Directory.Build.props`** (if present): set `<Major>`/`<Minor>`/`<Build>` to the new version's components and commit on the new branch before pushing.
5. **Push & track:** push both `main` and the new version branch to `origin`, using `-u` on the new branch so it tracks properly (`git push -u origin <version_branch>`).
