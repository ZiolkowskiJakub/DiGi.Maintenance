# GitHub Wiki — Home Page Template Specification

Template structure, compilation order, and parsing rules for repository `Home.md` wiki pages.

---

## 1. Landing Page Architecture

- **No H1 Header Rule:** GitHub Wiki renders "Home" as the page H1 header. `Home.md` **MUST NOT** include a top-level H1 title header.
- **5-Block Sequential Structure:** Compiled by central sync script (`SyncWiki.ps1`):
  1. **Block 1 — Repository Description:** Loaded from `$descriptions` table in sync script.
  2. **Block 2 — Target Framework Metadata:** Parsed dynamically from project `.csproj` files.
  3. **Block 3 — Custom Content Section:** Preserved user-authored markdown.
  4. **Block 4 — Dependencies List:** Generated dynamically from internal project references.
  5. **Block 5 — DiGi Ecosystem Footer:** Ecosystem cross-linking section.

---

## 2. Standard Template Structure

```markdown
[Repository Description]

* **Target Framework:** `[FrameworkName]`

[Custom Content Block - Preserved across syncs]

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

## 3. Parser & Preservation Rules

To protect custom content (Block 3) and prevent duplicated sections during synchronization, `SyncWiki.ps1` applies:

1. **Skip Flag (`$skipState`):** Triggers on encountering `^---`, `^### 🔗 Dependencies`, or `^## 🌐 DiGi Ecosystem`. All following lines in custom buffer are discarded.
2. **Line Omissions:** Discards lines matching `^# .*Wiki` or `Welcome to the .* wiki!`.
3. **Legacy Section Cleanups:** Filters legacy generated lines from custom content:
   - Target Framework labels: `^\s*\*\s+\*\*Target\s+Frameworks?:\*\*`
   - Ecosystem links: `^\s*\*\s+\[DiGi\.[A-Za-z0-9\.]+\]\(https://github\.com/ZiolkowskiJakub/`
   - Category labels: `^\s*\*\s+\*\*Foundational:\*\*`, `^\s*\*\s+\*\*Geometry\s+&\s+Graphics:\*\*`, etc.
   - Ecosystem attribution line: `^\s*\*Part of the DiGi software suite`
