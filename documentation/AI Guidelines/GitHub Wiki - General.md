# GitHub Wiki — General Guidelines

Structure, local layout, CI synchronization, and editing workflows for DiGi repository GitHub Wikis.

---

## 1. Wiki Architecture & Repository Layout

- **Wiki Remote:** Separate Git repository at `https://github.com/ZiolkowskiJakub/<repo>.wiki.git` (default branch: **`master`**).
- **Page Routing:** Page URL corresponds to `.md` filename without extension (`Home.md` → landing page).
- **Local Location:** Cloned under `DigiProject/wiki/<repo>.wiki` (e.g., `DigiProject/wiki/DiGi.Core.wiki/`). Each clone is a standalone repository.
  ```bash
  # Clone a missing wiki (from DigiProject workspace root):
  git clone https://github.com/ZiolkowskiJakub/<repo>.wiki.git "wiki/<repo>.wiki"
  ```

---

## 2. Page Types & Overwrite Constraints

| Page Type | Source & Generation | Modification Rule |
|---|---|---|
| **Auto-Generated API Pages** | Compiled from XML doc comments to `documentation/API/<Assembly>/*.md` during build, copied via CI. | **NEVER hand-edit.** Changes are overwritten by CI sync. Edit C# XML docs instead. |
| **Hand-Authored Pages** | `Home.md`, `Benchmark.md`, and guide pages created directly in wiki clone. | Edit and commit directly in wiki clone. CI sync never overwrites them. |

### Multi-Assembly Overview Page Rule
To prevent filename collisions across multi-assembly repositories, `Directory.Build.targets` enforces:
`<DefaultDocumentationAssemblyPageName>$(AssemblyName).Overview</DefaultDocumentationAssemblyPageName>`
Do NOT remove this setting or rename `<Assembly>.Overview.md` back to `index.md`.

---

## 3. CI Auto-Sync Mechanism (`SyncWiki.ps1`)

Workflow `.github/workflows/sync-wiki.yml` triggers on push to `main`/`master`:
1. Clones target wiki to temporary directory (`$env:TEMP\DiGi.WikiTemp_<repo>`).
2. Copies updated `documentation/API/*` markdown files from code repository into temp clone.
3. Commits (`chore: auto-update API documentation`) and pushes to `master` if diffs exist.

---

## 4. Manual & AI Editing Workflow

1. Open wiki clone: `cd DigiProject/wiki/<repo>.wiki`.
2. Fetch latest changes: `git pull`.
3. Edit **hand-authored** pages only (`Home.md`, `Benchmark.md`).
4. Cross-link related pages using markdown filenames.
5. Commit and push: `git push origin HEAD` (branch `master`).
6. **Mandatory Link Rule:** Link every new hand-authored page in `Home.md` for discoverability.

---

## Related Guidelines
- [GitHub Wiki - Benchmark.md](GitHub%20Wiki%20-%20Benchmark.md)
- [GitHub Wiki - Home.md](GitHub%20Wiki%20-%20Home.md)
