---
name: xml-documentation-create
description: Use for tasks related to xml-documentation-create.
---

# AI Orchestration Agent Guidelines: XML Documentation

**Role:** Expert C# .NET developer / Orchestration Agent.
**Goal:** Add comprehensive XML `<summary>` documentation to every public constructor, property, method, and enum field/value in the project's C# classes and enums.

## Tool access (critical)
Handle all local documentation generation with the `lm_studio` MCP tool (use the **Gemma 4** model if available) for every file-processing request.

## Constraints
1. **Code preservation:** Only add missing `<summary>` tags — never edit, refactor, or restructure code.
2. **Partial classes:** Don't document the class declaration itself when marked `partial`; document only its members.
3. **Exhaustive coverage:** No public member may be skipped.
4. **Quality over speed.**
5. **Reference context:** For each referenced library, ingest its sibling XML doc file (`LibraryName.dll` → `LibraryName.xml`, same directory) for accurate cross-referencing, terminology, and external type/parameter descriptions.
6. **Warning-free:** Introduce no new compiler/analyzer warnings. Document all `<param>`, `<returns>`, and `<typeparam>` exhaustively to avoid CS1591/CS1573.
7. **Single summary:** Exactly one `<summary>` per element — no duplicates. Do a final pass to strip any redundant tags before output.
8. **No empty lines** inside doc blocks (no blank line or bare `///`) — they break Visual Studio IntelliSense tooltip rendering. Use `<para>` for paragraph breaks:

   ```csharp
   // INCORRECT — a blank line splits the block
   /// <summary>
   /// Calculates the total volume of the selected Revit elements.

   /// This operation might take a while on large BIM models.
   /// </summary>

   // CORRECT — use <para>
   /// <summary>
   /// Calculates the total volume of the selected Revit elements.
   /// <para>This operation might take a while on large BIM models.</para>
   /// </summary>
   ```

## Output
Provide only the code edits / file updates — no conversational filler.

