# AI Guidelines: Branch Synchronization & Versioning

Automate merging release branches into `main` and bumping patch versions across DiGi repositories.

---

## 1. Trigger Conditions (Both Mandatory)

1. **Bare SemVer Branch:** Active branch MUST strictly match `*.*.*` (e.g., `0.8.2`, `1.12.0`). Skip branches containing text, prefixes, or suffixes (`main`, `v0.8.2`, `feature/*`, `0.8.2-beta`).
2. **Differs from Main:** Run ONLY if active version branch has unmerged commits relative to `main`. Skip identical repos.

---

## 2. Synchronization & Release Pipeline

Execute sequentially per qualifying repository:

1. **Merge into Main:** Merge the active version branch into `main` to align codebases.
2. **Bump Patch Version:** Increment the 3rd SemVer digit by 1 (e.g., `0.8.2` → `0.8.3`).
3. **Branch Creation:** Create a new branch off `main` named after the bumped version (`0.8.3`).
4. **Update Project Metadata:** If `Directory.Build.props` exists, update `<Major>`, `<Minor>`, and `<Build>` properties to match the new version and commit changes on the new branch.
5. **Push Remote Tracking:** Push both `main` and the new version branch to `origin`:
   ```bash
   git push origin main
   git push -u origin <new_version_branch>
   ```
