---
name: coding-templates
description: Use when creating a new project/solution from a template, or adding/modifying templates in the workspace's default templates/ folder.
---

# Coding — Templates

## 1. Templates Folder

- **Default Location:** `templates/` directory at the workspace root.
- **Missing Templates Rule:** If a required template is missing locally, save/download template files into `templates/` before scaffolding.

---

## 2. Available Templates

### 2.1 `DiGi.WebAPI.GLTF.Template`
- **Short Name:** `digiwebapigltftemplate`
- **Location:** `templates/DiGi.WebAPI.GLTF.Template/`
- **Description:** ASP.NET Core Web API pre-configured with the `DiGi.GLTF` 3D engine, binary glTF (`.glb`) streaming endpoints, response compression, and `IGLTFNodeConverter` plugin registration.
- **Placement Directive:** Scaffold solution folders **directly under the workspace root** (e.g. `workspace_root/MyNewWebAPI/`). Relative `HintPath` references (`..\..\DiGi.Core\bin\DiGi.Core.dll`) break if placed in deeper subfolders.

### 2.2 `DiGi.Template`
- **Short Name:** N/A (Repository Boilerplate)
- **Location:** `templates/DiGi.Template/`
- **Description:** Boilerplate template for new Visual Studio solutions establishing standard build configurations and coding styles.
- **Key Files & Configurations:**
  - **`Directory.Build.props`:** Enforces `<LangVersion>12.0</LangVersion>`, nullable context, implicit usings, `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`, and XML documentation generation for non-test projects.
  - **`Directory.Build.targets`:** Configures build-time `DefaultDocumentation` generation and defines `CopyFiles`/`CopyUserFiles` asset deployment targets.
  - **`.editorconfig`:** Enforces explicit typing (no `var`), block-scoped namespaces, collection expressions (`[]`), and target-typed `new()`.
  - **`DefaultDocumentation.json`:** API documentation schema configuration.
  - **`.gitignore`:** Ignores build artifacts and enforces exclusion of sensitive files in `[Uu]ser [Ff]iles/`.

---

## 3. Template Management Commands

Run commands from workspace root:

```powershell
# Install template locally
dotnet new install "templates/DiGi.WebAPI.GLTF.Template"

# Scaffold new project under workspace root
dotnet new digiwebapigltftemplate -n MyGLTFHost -o "MyGLTFHost"

# Uninstall template
dotnet new uninstall "templates/DiGi.WebAPI.GLTF.Template"
```

---

## 4. Standing Up A New Repository

Scaffolding the solution is the small half. A repository is not finished until it carries the same
furniture as its siblings, and none of the steps below are implied by `dotnet new` or by creating the
repository through the GitHub UI. `DiGi.GIS.YOLO.UI` and `DiGi.YOLO.ONNX` are the two most recent
worked examples; copy from whichever is closer.

### The one that leaks secrets

**A repository created through the GitHub UI does not ignore `user files/`.** GitHub seeds it with the
stock `VisualStudio.gitignore`, which has no `[Uu]ser [Ff]iles/` rule at all - the template's does, at
line 378. Until it is replaced, the folder holding `*.conf` connection strings, API keys and machine
paths is tracked, and the first `git add -A` commits them. **Replace `.gitignore` from the template
before the first commit**, and prove it:

```powershell
git check-ignore -v "user files/x"   # must name the [Uu]ser [Ff]iles/ rule
```

### The rest, in order

1. **Root files from `templates/DiGi.Template/`:** `.editorconfig`, `.gitignore`,
   `Directory.Build.props`. Set `<Major>`/`<Minor>`/`<Build>` to match the version branch below.
2. **`Directory.Build.targets`, `DefaultDocumentation.json`, `.github/workflows/sync-wiki.yml`:** copy
   from a sibling repository. `ApplyDocumentationSetup.ps1` writes all three, but it `Set-Content
   -Force`s them into **every** `DiGi.*` repository - needless churn across 60+ repositories when one
   is being set up.
3. **`.agents/`** via `UpdateAgents.ps1`, **README guidelines block** via `UpdateReadmes.ps1`. Write the
   repository-specific README intro *first*: `UpdateReadmes.ps1` appends the canonical block below
   whatever is already there. Both scripts sweep every repository and **commit unless `-NoCommit` is
   passed**; they stage only `.agents` and `README.md`, so unrelated in-flight work elsewhere cannot be
   swept in, but check `git status` before running them anyway.
4. **Labels:** `SyncLabelsAllRepos.ps1 -Repo <name>`. A new repository has GitHub's defaults and **none
   of the standard taxonomy**, so the first issue filed against it cannot carry the mandatory
   `type:`/`priority:`/`ai:` labels `GitHub - Issues.md` requires. `DiGi.YOLO.ONNX` hit exactly this.
5. **`BuildAll.ps1`:** add the `.slnx` **in dependency order**, not alphabetically - the list is
   consumed top to bottom and a repository placed before what it references by `HintPath` builds
   against a stale or absent assembly.
6. **`CheckHostDependencies.ps1`:** add a `$DeploymentUnits` entry only if the repository produces an
   `Exe`/`WinExe`/web host. A class library has no deployment unit of its own.
7. **Version branch:** a bare SemVer branch off `main` per `GitHub - Branch Synchronization.md`, pushed
   with `git push -u origin <version>`, with `Directory.Build.props` agreeing.
8. **Repository description:** `gh repo edit <owner>/<name> --description "..."` - it is empty by
   default and shows on every listing.
