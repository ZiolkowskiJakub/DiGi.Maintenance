---
name: xml-documentation-create
description: Use when adding missing XML <summary> docs to public members without touching existing docs or code logic.
---

# AI Guidelines: XML Documentation Generation

Add comprehensive XML `<summary>` documentation to every public constructor, property, method, and enum field/value in target C# files.

---

## Tooling Requirements

- Process all local documentation requests using the `lm_studio` MCP tool (prefer **Gemma 4** model if available).

---

## Directives & Constraints

1. **Code Preservation:** Add missing XML doc tags only. Never edit, refactor, or alter C# logic.
2. **Partial Classes:** Do not document `partial` class declarations — document member declarations only.
3. **Exhaustive Coverage:** Document all public members without exception.
4. **External Reference Context:** Ingest sibling XML doc files (`LibraryName.dll` → `LibraryName.xml`) from the same directory for accurate cross-referencing and parameter descriptions.
5. **Zero Compiler Warnings:** Document all `<param>`, `<returns>`, and `<typeparam>` tags to eliminate CS1591 and CS1573 analyzer warnings. Reorder `<param>` tags to mirror method parameter order.
6. **Single Summary Tag:** Ensure exactly one `<summary>` block per element. Strip redundant tags.
7. **No Blank Lines in Doc Blocks:** Prohibit empty lines or bare `///` lines inside doc comments (breaks Visual Studio tooltips). Use `<para>` tags for paragraph breaks:

```csharp
/// <summary>
/// Calculates total volume of selected elements.
/// <para>Operation may take time on large models.</para>
/// </summary>
```

8. **Output Format:** Return modified code files only. Omit conversational intro and outro text.
