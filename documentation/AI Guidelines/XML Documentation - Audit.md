# AI Guidelines: XML Documentation Audit & Synchronization

Audit, update, and synchronize XML documentation (`<summary>`, `<param>`, `<returns>`, `<typeparam>`) for all public constructors, properties, methods, and enum values. Match existing code logic and signatures exactly.

---

## Tooling Requirements

- Process documentation audit tasks using the `lm_studio` MCP tool (prefer **Gemma 4** model if available).

---

## Directives & Constraints

1. **Code Preservation & Sync:** Modify `///` comments only — never alter C# logic. Rewrite outdated comments, delete `<param>` tags for removed parameters, and add tags for new parameters.
2. **Explicit Typing:** Enforce explicit typing (no `var`) in any code touched.
3. **Signature Synchronization:** Match doc parameters to method signatures exactly. Reorder `<param>` tags whenever parameter order changes (e.g. `CancellationToken` placement).
4. **Zero Analyzer Warnings:** Document all `<param>`, `<returns>`, and `<typeparam>` tags to avoid CS1591 and CS1573 warnings.
5. **Partial Classes:** Do not document `partial` class declarations — document member declarations only.
6. **Reference Context:** Ingest sibling XML doc files (`LibraryName.dll` → `LibraryName.xml`) for external type definitions and terminology.
7. **Single Summary Tag:** Overwrite outdated summaries — never append duplicate `<summary>` blocks.
8. **No Blank Lines in Doc Blocks:** Prohibit empty lines or bare `///` lines inside doc comments. Use `<para>` tags for paragraph breaks:

```csharp
/// <summary>
/// Calculates total volume of selected elements.
/// <para>Operation may take time on large models.</para>
/// </summary>
```

9. **Output Format:** Return updated code files only. Omit conversational text.
