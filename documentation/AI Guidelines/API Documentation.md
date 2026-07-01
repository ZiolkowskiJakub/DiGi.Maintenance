# AI Guidelines: Workspace API Documentation

## 🔍 Locating API Reference
To minimize token consumption and avoid parsing full implementation files, you MUST consult the generated Markdown documentation first when exploring type schemas, namespaces, and public API interfaces.

* **API Docs Path**: Look in the `documentation/API/[AssemblyName]/` directory of each active workspace.
* **Fallback**: If the `documentation/API/` folder does not exist, fall back to scanning standard C# source files and `/bin/*.xml` files.
* **Structure**: Each assembly has its own directory. Inside, files are split by **Namespace** (e.g., `DiGi.Core.Classes.md`).
* **Content**: These files contain exact signatures and `<summary>` descriptions of all public classes, constructors, methods, properties, and enums.

## ⚠️ Constraints
1. **Do Not Re-Read Source Files for API Signatures**: If you need to understand the public methods available on a class, read its corresponding namespace markdown file. Only view the actual `.cs` source code files if you are actively editing them or need to understand internal business logic.
2. **Synchronized Build**: The API documentation is automatically regenerated on every compilation. If you make modifications to code signatures or XML comments, compile the project to ensure the `.md` files are updated.
