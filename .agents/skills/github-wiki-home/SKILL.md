---
name: github-wiki-home
description: Use when creating or editing a repository's Wiki Home page - template structure, parsing/preservation rules for the sync script, and the standard DiGi ecosystem footer.
---

# GitHub Wiki — Home Page Template Specification

This document defines the template structure, parsing rules, and compilation behavior for the home page (`Home.md`) of all GitHub Wiki repositories in the DiGi project suite.

---

## 1. Landing Page Architecture

Because GitHub Wiki hard-codes the landing page filename to `Home.md` and dynamically renders "Home" as the page-level H1 title at the top, the file contents **must not** contain a redundant H1 title header.

The page is compiled by the central synchronization script (`update_wikis_and_readmes.ps1`). It splits the file structure into the following sequential blocks:

```
┌────────────────────────────────────────────────────────────┐
│ BLOCK 1 — Repository Description (Dynamic/Static)          │
│   Loaded from the $descriptions table in the sync script.  │
├────────────────────────────────────────────────────────────┤
│ BLOCK 2 — Target Framework Metadata                        │
│   Parsed dynamically from repository *.csproj files.       │
├────────────────────────────────────────────────────────────┤
│ BLOCK 3 — Custom Content Section (Preserved)               │
│   Any custom user markdown added between metadata/footer.  │
├────────────────────────────────────────────────────────────┤
│ BLOCK 4 — Dependencies list                                │
│   Generated dynamically based on internal project refs.    │
├────────────────────────────────────────────────────────────┤
│ BLOCK 5 — DiGi Ecosystem Footer                            │
│   Standard cross-linking section for ecosystem discovery.  │
└────────────────────────────────────────────────────────────┘
```

---

## 2. Template Structure

The standard template structure of `Home.md` is specified below:

```markdown
[Repository Description]

* **Target Framework:** `[FrameworkName]` (or **Target Frameworks:** `[FW1]`, `[FW2]`)

[Custom Content Block - User changes are preserved here]

### 🔗 Dependencies
*   [[DependencyRepoName1]|https://github.com/ZiolkowskiJakub/[DependencyRepoName1]/wiki]
*   [[DependencyRepoName2]|https://github.com/ZiolkowskiJakub/[DependencyRepoName2]/wiki]

---

## 🌐 DiGi Ecosystem
* **Foundational:** [DiGi.Core](https://github.com/ZiolkowskiJakub/DiGi.Core/wiki) | [DiGi.Math](https://github.com/ZiolkowskiJakub/DiGi.Math/wiki) | [DiGi.Unit](https://github.com/ZiolkowskiJakub/DiGi.Unit/wiki) | [DiGi.Log](https://github.com/ZiolkowskiJakub/DiGi.Log/wiki)
* **Geometry & Graphics:** [DiGi.Geometry](https://github.com/ZiolkowskiJakub/DiGi.Geometry/wiki) | [DiGi.GLTF](https://github.com/ZiolkowskiJakub/DiGi.GLTF/wiki) | [DiGi.Rhino](https://github.com/ZiolkowskiJakub/DiGi.Rhino/wiki)
* **GIS & Data:** [DiGi.GIS](https://github.com/ZiolkowskiJakub/DiGi.GIS/wiki) | [DiGi.OSM](https://github.com/ZiolkowskiJakub/DiGi.OSM/wiki) | [DiGi.BDOT10k](https://github.com/ZiolkowskiJakub/DiGi.BDOT10k/wiki)
* **Simulation:** [DiGi.Analytical](https://github.com/ZiolkowskiJakub/DiGi.Analytical/wiki) | [DiGi.Solar](https://github.com/ZiolkowskiJakub/DiGi.Solar/wiki) | [DiGi.Tas](https://github.com/ZiolkowskiJakub/DiGi.Tas/wiki)

*Part of the DiGi software suite for BIM and CAD integrations.*
```

---

## 3. Parsing Rules & Preservation Logic

To preserve manual edits in **Block 3** and prevent duplicate headers, links, and footers from accumulating on subsequent syncs, the synchronization script applies the following rules:

1. **Persistent Skip Flag:**
   A `$skipState` flag triggers when hitting lines matching `^---` (old footer), `^### 🔗 Dependencies`, or `^## 🌐 DiGi Ecosystem`. Once triggered, all subsequent lines are discarded from the custom content buffer.
2. **Line Omissions:**
   The parser skips lines matching standard titles (`^# .*Wiki`) or standard welcome text (`Welcome to the .* wiki!`).
3. **Legacy Cleanups:**
   The parser actively filters out and discards individual lines belonging to dynamically compiled sections if they exist in the custom content section due to legacy script runs:
   - Target framework labels: `^\s*\*\s+\*\*Target\s+Frameworks?:\*\*`
   - Ecosystem links: `^\s*\*\s+\[DiGi\.[A-Za-z0-9\.]+\]\(https://github\.com/ZiolkowskiJakub/`
   - Ecosystem category labels: `^\s*\*\s+\*\*Foundational:\*\*`, `^\s*\*\s+\*\*Geometry\s+&\s+Graphics:\*\*`, etc.
   - Core attribution line: `^\s*\*Part of the DiGi software suite`

