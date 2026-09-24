---
name: github-plan-files
description: "Use when an implementation plan exists or a commit/push is about to happen in a DiGi repository - plans live in the local plans folder outside the working tree, a pre-commit sweep keeps plan/scratch *.md out of every commit and push, and the default action is deleting the temporary implementation plan in the same session the issue closes (no archiving into the repo; explicit user instruction wins)."
---

# AI Guidelines: Plan Files

Plan files are session working papers, not project artifacts. They live outside the repository,
are never committed, and are deleted by default when the issue they implement is closed.

---

## 1. Where Plan Files Live — Outside the Repository

1. **Default destination:** the local plans folder outside every repository working directory
   (defined in the machine-level `AGENTS.md` — the global per-machine preferences). When asked to
   create an implementation, design, or issue plan and the user names no destination, save it there.
2. **Never into the repository working tree by default** — not at the repo root, not under
   `documentation/`, not beside the code it plans. Even when the user asks for the plan to be
   written into the working tree, it is temporary by definition and must be gone before the next
   commit (§2).
3. **Scratch body files are plan files too.** The temporary markdown written to post issue bodies
   or comments via `--body-file` (`GitHub - Issues.md` §1) is a scratch artifact: write it to the
   scratch folder, use it, delete it. It never enters the repository.

## 2. Commit & Push Hygiene — the Repo Stays Free of Plan Files

A commit must never add, modify, or resurrect a plan file — especially a `*.md` working paper:

1. **Pre-commit sweep (mandatory).** Before every `git add` / `git commit` / `git push`, inspect
   what the change set touches:
   ```bash
   git status --porcelain
   git diff --name-only --cached
   ```
   Every untracked or staged `.md` file that is a plan, draft, or working note (implementation
   plan, design sketch, analysis dump, `plan.md`, `TODO-*.md`, `temp_body.md`) is excluded from
   the commit and deleted once its job is done (§3).
2. **No blind `git add .` / `git add -A`.** Stage explicit paths (`git add <path> ...`) — a
   blanket add is how plan files end up in history.
3. **`*.md` is the trap, not the rule.** The sweep targets plan/draft/scratch markdown, never the
   repository's legitimate documentation (`README.md`, `documentation/**`, wiki sources). Unsure
   whether a file is a plan? Ask: "permanent project artifact, or working paper of this session?"
   The latter does not belong in the commit.
4. **A plan already tracked** (a previous session committed it) is removed from the index and
   working tree, with the removal committed alongside the work that made the plan stale:
   ```bash
   git rm "path/to/plan.md"
   ```
   A plan in history teaches the next agent to keep one; the removal is part of the fix.
5. **A `.gitignore` entry for scratch names is a safety net at best** — it hides the mistake, it
   does not delete the file. The rule is delete, not hide.

## 3. Default: Delete the Plan When the Issue Closes

- **The deletion trigger is issue closure.** When the issue a plan implemented is closed (with its
  resolution comment — `GitHub - Issues.md` §3), delete the plan file in the same session. The
  closed issue, its resolution comment, and the commits are the permanent record; the plan is the
  draft they replaced.
- **Sub-issues:** delete each sub-issue's plan as that sub-issue closes; the parent tracking
  issue's plan goes with the parent (the Sub-issues table and the per-repository resolution
  comments are the surviving record — `GitHub - Sub-Issues.md`).
- **No archiving into the repository** — no `plans/` folder, no `archive/` folder, no "moved to
  `documentation/`". If a design decision from the plan deserves to survive, promote it to the
  permanent place it belongs in (the issue body or a comment, a wiki page, `documentation/`)
  before deleting the plan.
- **Report the deletion in one line** of the session summary (e.g. "plan for
  `DiGi.GIS.PostgreSQL#83` deleted after closure") so the user can notice if they wanted it kept.

## 4. Exception — When the User Wants the Plan Kept

The default is delete-on-close, but an explicit user instruction wins:

- **The user asked for the plan to be committed** (e.g. it doubles as design documentation):
  commit it deliberately — named like documentation (not `plan.md` / `draft.md`), placed where
  documentation lives (`documentation/`), and referenced from `README.md` or the wiki so it stays
  discoverable. It is then a documentation change to be reviewed as one, not a leftover.
- **The issue is still open:** keep the plan in the local plans folder — never in the repository
  working tree — so the next session can resume from it. Delete it only on closure.
- **When in doubt, ask:** "keep this plan, or delete it now that the issue is closed?" beats both
  deleting something the user wanted and committing something they did not.
