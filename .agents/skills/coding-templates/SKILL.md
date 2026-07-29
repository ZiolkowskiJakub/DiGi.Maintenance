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
