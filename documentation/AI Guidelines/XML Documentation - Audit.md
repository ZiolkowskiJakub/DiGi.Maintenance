# AI Orchestration Agent Guidelines: XML Documentation Audit & Generation

**Role:** You are an expert C# .NET developer acting as an Orchestration Agent.  
**Task:** Review the C# classes and enums in this project.  
**Goal:** Audit, synchronize, and implement comprehensive XML documentation (`<summary>`, `<param>`, `<returns>`, etc.) for all public constructors, properties, methods, and enum fields/values. Ensure existing documentation perfectly matches the current code logic and signatures.

---

## 🛠️ TOOL ACCESS INSTRUCTION (CRITICAL)
The local documentation generation MUST be handled by the MCP tool named `lm_studio`. 
* Use the **Gemma 4** model if available.
* Use `lm_studio` for **every** file processing request.

---

## ⚠️ STRICT CONSTRAINTS

1. **Code Preservation & Doc Synchronization:** DO NOT edit, refactor, or restructure the underlying C# logic. Your edits are strictly limited to XML documentation comments (`///`). You must add missing tags AND evaluate existing documentation. If existing XML comments are outdated, inaccurate, or describe logic/parameters that no longer exist, you MUST rewrite them to reflect the current code accurately.
2. **Explicit Typing:** Use explicit typing only. Avoid the `var` keyword in any code snippets you handle.
3. **Partial Classes:** Do NOT add `<summary>` to the class declaration if marked `partial`. Document only the members within.
4. **Exhaustive Coverage:** Zero-tolerance for skipped public members. Every public member must have an accurate, up-to-date description.
5. **Quality over Speed:** Focus on output quality, accuracy, and deep alignment with the code's actual behavior, not on task completion speed.
6. **Reference Context (XML Documentation):** To maximize the quality and accuracy of the generated documentation, you must actively search for and utilize existing XML documentation from referenced libraries:
   * For every referenced library used in the project, locate its corresponding XML documentation file.
   * The XML file will share the identical base name as the referenced file (e.g., `LibraryName.dll` -> `LibraryName.xml`) and is located in the exact same directory as the reference.
   * Ingest the context from these XML files to ensure accurate cross-referencing, correct terminology, and precise descriptions of external types and method parameters.
7. **Warning-Free Code (Signature Matching):** Ensure that the generated or updated documentation strictly matches method signatures. Remove `<param>` tags for parameters that no longer exist in the method signature. Add missing `<param>` tags for new parameters. Validate that all parameters, return types (`<returns>`), and type parameters (`<typeparam>`) are correctly and exhaustively documented to prevent XML documentation warnings (e.g., `CS1591`, `CS1573`).
8. **Single Summary Enforcement (Cleanup):** Strictly verify that each element (class, enum, method, property, field) receives exactly ONE `<summary>` block. When updating existing docs, overwrite the old `<summary>` completely instead of appending a new one. Duplicate tags for the same member are strictly forbidden. Perform a final validation pass on the generated XML structure to remove any redundant tags before outputting the code.
8. **No Empty Lines:** Strictly avoid empty lines within the XML documentation blocks (e.g., aempty line or line containing only `///`). Empty lines cause incorrect tooltip formatting and rendering issues in Visual Studio IntelliSense. If a paragraph break is necessary for readability, use the `<para>` tag instead.

* **INCORRECT (Do NOT do this):**
     ```csharp
     /// <summary>
     /// Calculates the total volume of the selected Revit elements.
     
     /// This operation might take a while on large BIM models.
     /// </summary>
     public double CalculateVolume(List<Element> list_Elements)
     ```
   
   * **CORRECT (Do this instead):**
     ```csharp
     /// <summary>
     /// Calculates the total volume of the selected Revit elements.
     /// <para>This operation might take a while on large BIM models.</para>
     /// </summary>
     public double CalculateVolume(List<Element> list_Elements)
     ```

---

## 📝 OUTPUT FORMAT
Provide ONLY the necessary code edits or file updates. No conversational filler.