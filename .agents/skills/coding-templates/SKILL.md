---
name: coding-templates
description: Use for tasks related to coding-templates.
---

# Coding — Templates

This guideline documents the default location, installation, and usage patterns for project and solution templates within the DiGi project repositories.

## 1. Templates Folder

The default location for all project and solution templates is the `templates/` directory located at the root of the workspace:
- **Default path:** `templates/`

### AI Behavior for Missing Templates
If a task requires a template repository or project configuration that is not currently available locally, the AI model must download or save the template contents into this default `templates/` directory first before attempting to scaffold or use it.

---

## 2. Available Templates

### 2.1 DiGi.WebAPI.GLTF.Template
- **Short Name:** `digiwebapigltftemplate`
- **Location:** `templates/DiGi.WebAPI.GLTF.Template/`
- **Description:** ASP.NET Core Web API pre-configured with the generic `DiGi.GLTF` 3D visualization engine. It includes generic `GLTFScene` composition and binary glTF (`.glb`) streaming endpoints, response compression, and the `IGLTFNodeConverter` plugin registration hook.

#### Key Architectural Rules:
- **Solution Placement:** Always create/scaffold the solution folder **directly under the workspace root** (e.g. `MyNewWebAPI/` inside the workspace root folder) so relative `HintPath` references to `DiGi.Core`, `DiGi.Geometry`, and `DiGi.GLTF` resolve correctly.
- **Reference Setup:** A pre-configured project template will reference the main DLLs using relative paths (e.g., `..\..\DiGi.Core\bin\DiGi.Core.dll`). Putting the project in a deeper subfolder will break references.

### 2.2 DiGi.Template
- **Short Name:** N/A (Repository Boilerplate)
- **Location:** `templates/DiGi.Template/`
- **Description:** Foundational boilerplate template for all new Visual Studio 2026 solutions. It establishes standard solution-level configurations, coding styles, and build patterns.

#### Key Architectural Rules & Boilerplate Files:
- **`Directory.Build.props`**: Sets C# 12+ versioning (`<LangVersion>12.0</LangVersion>`), nullable context, implicit usings, warning levels (`TreatWarningsAsErrors`), and automatically enables XML documentation file generation for non-test C# projects.
- **`Directory.Build.targets`**: Enables build-time `DefaultDocumentation` page generation (suppressing CS1591 only for test projects) and contains centralized targets `CopyFiles` and `CopyUserFiles` to copy runtime assets from `files/` and `user files/` directories directly into the build output path.
- **`.editorconfig`**: Enforces coding guidelines, making violations of the "no-var" rule, block-scoped namespaces, collection expressions (`[]`), and target-typed `new()` compile as errors.
- **`DefaultDocumentation.json`**: Configures the API documentation generation schema.
- **`.gitignore`**: Excludes build logs, user settings, Visual Studio caches, and enforces exclusion of credentials and secrets under the `[Uu]ser [Ff]iles/` directory.

---

## 3. Template Management Commands

All commands should be executed from the workspace root directory.

### Install a Template
To install a template locally so it becomes visible to dotnet CLI and Visual Studio:
```powershell
dotnet new install "templates/DiGi.WebAPI.GLTF.Template"
```

### Scaffold a New Project
To scaffold a new project using the installed template, specify the output folder directly under the workspace root:
```powershell
dotnet new digiwebapigltftemplate -n MyGLTFHost -o "MyGLTFHost"
```

### Uninstall a Template
To remove a template from dotnet CLI and Visual Studio:
```powershell
dotnet new uninstall "templates/DiGi.WebAPI.GLTF.Template"
```

