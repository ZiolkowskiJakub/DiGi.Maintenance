---
name: coding-api-documentation
description: Use when looking up or exploring type schemas, namespaces, or public APIs in the codebase. Guides on consulting the generated markdown API docs before opening C# source files.
---

# AI Guidelines: Workspace API Documentation

## Locating API reference
To save tokens, consult the generated Markdown API docs before parsing `.cs` source when exploring type schemas, namespaces, or public API.

- **Path:** `documentation/API/[AssemblyName]/` in each active workspace — one directory per assembly, split by **namespace** (e.g. `DiGi.Core.Classes.md`). These files hold exact signatures and `<summary>` descriptions for all public classes, constructors, methods, properties, and enums.
- **Fallback:** if `documentation/API/` is absent, scan the C# source and `/bin/*.xml` files.

## Constraints
1. **Don't re-read source for signatures:** to see a class's public API, read its namespace markdown. Open `.cs` source only when editing it or when you need internal business logic.
2. **Synchronized build:** the API docs regenerate on every compilation — after changing code signatures or XML comments, compile so the `.md` files update.
