---
name: github-wiki-general
description: Use for tasks related to github-wiki-general.
---

# GitHub Wiki — General

How DiGi wikis are structured, cloned locally, kept in sync, and hand-edited. Read this before touching
any wiki page. For benchmark pages see [`GitHub Wiki - Benchmark.md`](GitHub%20Wiki%20-%20Benchmark.md).

## What a DiGi wiki is
- Each code repo can have a **GitHub Wiki** — a *separate* git repo at
  `https://github.com/ZiolkowskiJakub/<repo>.wiki.git`, rendered at `.../<repo>/wiki`. It has its own
  history and remote, default branch **`master`**. A page's URL is its `.md` filename without the
  extension (`Benchmark.md` → `.../wiki/Benchmark`; `Home.md` → the landing page).
- A wiki repo exists once it has at least one page (`Home`); all DiGi.* repos with wikis enabled
  already do.

## Local layout — `DigiProject/wiki/`
Wiki clones live under **`wiki/`** under the `DigiProject` workspace root, one folder per wiki named
`<repo>.wiki` (e.g. `DiGi.Core.wiki/`, `DiGi.Geometry.wiki/`, `DiGi.ComputeSharp.wiki/`,
`DiGi.Weather.wiki/`). `DigiProject/` is not a git repo, so each clone is standalone (own `.git`,
URL-based remote); its on-disk location is irrelevant to git and CI, so it can be moved freely. Clone a
missing wiki here:

```
# Run from the DigiProject workspace root:
git clone https://github.com/ZiolkowskiJakub/<repo>.wiki.git "wiki/<repo>.wiki"
```

## Two kinds of page
- **Auto-generated API pages** — built from XML doc comments into `documentation/API/<Assembly>/*.md`
  in the code repo on every build, then copied into the wiki by CI. **Never hand-edit** — the next sync
  overwrites them; change the C# XML docs and rebuild instead.
- **Hand-authored pages** — `Home.md`, `Benchmark.md`, and other guide pages. The sync never touches
  these (it only adds/updates API pages). Edit them directly in the wiki clone.

### Multi-assembly repos need a unique assembly page name
`DefaultDocumentation` names a multi-namespace assembly's overview page `index.md` unless
`DefaultDocumentationAssemblyPageName` is set. The wiki sidebar shows only the filename, not the
folder, so a repo with 2+ assemblies (e.g. `DiGi.Communication` + `DiGi.Communication.ComputeSharp`)
ends up with multiple pages that all display as the same bare word "index". `Directory.Build.targets`
(both the shared one written by `ApplyDocumentationSetup.ps1` and `templates/DiGi.Template`'s) sets
`<DefaultDocumentationAssemblyPageName>$(AssemblyName).Overview</DefaultDocumentationAssemblyPageName>`
to avoid this — don't remove it, and don't hand-rename the resulting `<Assembly>.Overview.md` pages
back to `index.md`.

## CI auto-sync (independent of local clones)
Each code repo has `.github/workflows/sync-wiki.yml`. On push to `main`/`master` it checks out
`DiGi.Maintenance` and runs `DiGi.Maintenance/Scripts/SyncWiki.ps1 -RepoPath <workspace>`, which:

1. Derives the wiki URL from the code repo's `origin` (`…<repo>.git` → `…<repo>.wiki.git`), injecting
   `WIKI_SYNC_PAT`/`GITHUB_TOKEN` for auth.
2. Clones that wiki into a temp dir (`$env:TEMP\DiGi.WikiTemp_<repo>`) — not the `DigiProject/wiki/`
   clone.
3. Copies `documentation/API/*` from the code repo into the temp clone.
4. Commits (`chore: auto-update API documentation`) and pushes **only if there are changes**, then
   deletes the temp dir.

Because the sync uses its own throwaway clone, the `DigiProject/wiki/` clones have no effect on CI and
vice-versa — the only collision risk is hand-editing an auto-generated API page, which the sync reverts.

## Editing workflow (manual / AI)
1. `cd` to the clone under `DigiProject/wiki/<repo>.wiki` (clone it there first if missing).
2. `git pull` — CI may have pushed API updates since you last synced.
3. Edit **hand-authored** pages only; match the existing page style and cross-link related pages by
   filename.
4. Commit and `git push origin HEAD` (branch `master`). Git identity and `credential.helper=manager`
   are preconfigured on these clones, so pushes are non-interactive.
5. Verify the rendered page at `https://github.com/ZiolkowskiJakub/<repo>/wiki/<PageName>` (GitHub may
   serve a cached copy briefly).

Link every new hand-authored page from `Home.md` so it is discoverable.

## Related
- [`GitHub Wiki - Benchmark.md`](GitHub%20Wiki%20-%20Benchmark.md) — required structure for `Benchmark`
  pages.
- `DiGi.Maintenance/Scripts/SyncWiki.ps1` — the sync implementation.

