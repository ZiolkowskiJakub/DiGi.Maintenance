---
name: xml-documentation-audit
description: Use when auditing or synchronizing existing XML docs against current signatures - a superset of xml-documentation-create that also rewrites stale summaries and fixes mismatched param/returns tags.
---

# AI Orchestration Agent Guidelines: XML Documentation Audit & Generation

**Role:** Expert C# .NET developer / Orchestration Agent.
**Goal:** Audit, synchronize, and add comprehensive XML documentation (`<summary>`, `<param>`, `<returns>`, `<typeparam>`) for every public constructor, property, method, and enum field/value. Existing docs must match the current code logic and signatures exactly.

## Tool access (critical)
Handle all local documentation generation with the `lm_studio` MCP tool (use the **Gemma 4** model if available) for every file-processing request.

## Constraints
1. **Code preservation & sync:** Edit only `///` comments — never change C# logic. Add missing tags, and rewrite any existing comment that is outdated, inaccurate, or describes logic/parameters that no longer exist.
2. **Explicit typing:** No `var` in any code snippet you touch.
3. **Partial classes:** Don't document the class declaration itself when marked `partial`; document only its members.
4. **Exhaustive coverage:** Every public member must have an accurate, up-to-date description.
5. **Quality over speed** — prioritize accuracy and alignment with the code's actual behavior.
6. **Reference context:** For each referenced library, ingest its sibling XML doc file (`LibraryName.dll` → `LibraryName.xml`, same directory) for accurate cross-referencing, terminology, and external type/parameter descriptions.
7. **Signature matching:** Docs must match signatures exactly — remove `<param>` tags for parameters that no longer exist, add tags for new ones. Document all `<param>`, `<returns>`, and `<typeparam>` to avoid CS1591/CS1573.
8. **Single summary:** Exactly one `<summary>` per element. When updating, overwrite the old one — never append. Do a final pass to strip any redundant tags.
9. **No empty lines** inside doc blocks (no blank line or bare `///`) — they break Visual Studio IntelliSense tooltip rendering. Use `<para>` for paragraph breaks:

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

