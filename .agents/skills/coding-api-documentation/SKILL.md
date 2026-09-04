---
name: coding-api-documentation
description: Use when looking up a type's public API - consult the generated documentation/API/ markdown before opening .cs source to check signatures, namespaces, or <summary> descriptions.
---

# AI Guidelines: Workspace API Documentation

## API Reference Lookup

Consult generated Markdown API docs before parsing `.cs` source to save context tokens.

- **Primary Path:** `documentation/API/[AssemblyName]/` in active workspace (split by namespace, e.g., `DiGi.Core.Classes.md`). Contains exact signatures and `<summary>` docs for public members.
- **Fallback Path:** Scan C# source and `/bin/*.xml` files if `documentation/API/` is absent.

## Directives

1. **Avoid Re-reading Source:** Read namespace `.md` files to inspect public class/method signatures. Open `.cs` files only when modifying business logic.
2. **Synchronized Build:** API docs regenerate on compile. Rebuild the project after changing signatures or XML comments to update markdown docs.
