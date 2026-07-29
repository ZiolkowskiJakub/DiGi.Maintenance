## 💻 Coding Guidelines for Developers & AI Agents

To maintain codebase health, performance, and compatibility within Visual Studio 2026 / C# 10+ environments, all developers and AI agents must strictly comply with these guidelines.

### 1. General Coding Standards
1. **English only** — identifiers and comments.
2. **Explicit typing — no `var`** (unless the compiler forces it, e.g. anonymous types). Use target-typed `new(...)` when the type is declared (avoids IDE0090): `PointNode pointNode = new();`. Use collection expressions `[]` for collections (avoids IDE0028): `List<int> numbers = [];`, `int[] array = [1, 2, 3];`.
3. **Variable naming:** start with the type name in camelCase, adding a `_`-suffixed qualifier when needed (`PointNode pointNode_Base`, `pointNode_Temp`).
   - **Collections:** don't prefix with the collection type — use the element type pluralized (`FilterConditions`, not `Conditions`/`listConditions`; `FilterGroups`, not `Groups`/`listGroups`).
   - **Property matching its value type:** if a value type is fully descriptive and unique in the class, name the property after the type (`public AggregateFunction AggregateFunction { get; set; }`).
   - **Primitives** may use plain camelCase (`double tolerance`, `string name`, `int count`).
4. **Zero warnings/analyzer messages** — nullability, parameter validation, clean code.
5. **C# 10+ / C# 13/14** (`LangVersion` ≥ 10) — modern features (enhanced pattern matching, target-typed `new`, collection expressions, `System.Threading.Lock`, etc.) are fine within these architectural constraints. **Namespaces must be block-scoped** (as in every example below); file-scoped namespaces are disallowed and enforced via `.editorconfig` (`csharp_style_namespace_declarations = block_scoped`). See `Coding - Editor Config.md` for the unified baseline rules.
6. **Line breaks in parameters:** If a method or constructor has fewer than 6 input parameters, do not break lines between parameters.
   - **Correct:**
     ```csharp
     public void Calculate(double centerX, double centerY, double radius, double? storeyHeight = null)
     {
     }
     ```
   - **Incorrect:**
     ```csharp
     public void Calculate(
         double centerX,
         double centerY,
         double radius,
         double? storeyHeight = null)
     {
     }
     ```
7. **Async method naming:** All asynchronous method names must end with `Async`.
   - **Example:**
     ```csharp
     public async Task<IActionResult> GetDetailsByReferenceAsync([FromQuery(Name = "reference")] string? reference)
     ```
8. **`CancellationToken` is always the LAST parameter (CA1068).** This holds for every method — public, private, static, extension, local — and for every overload. When adding a new optional parameter to an existing signature, insert it *before* the token; never append after it.
   - **Correct:**
     ```csharp
     public static async Task<bool> ClearAsync(NpgsqlConnection? npgsqlConnection, string tableName, int commandTimeout = 30, CancellationToken cancellationToken = default)
     ```
   - **Incorrect** — appending after the token is the usual way this rule gets broken:
     ```csharp
     public static async Task<bool> ClearAsync(NpgsqlConnection? npgsqlConnection, string tableName, CancellationToken cancellationToken = default, int commandTimeout = 30)
     ```
   - The `<param>` tags in the XML doc block must be reordered to match, so the docs still mirror the signature exactly.
   - **Pass the token by name at call sites** — `cancellationToken: cancellationToken` — whenever intervening parameters are left at their defaults. Positional calls silently rebind if the signature is ever reordered again; named arguments turn a reordering into a compile error rather than a wrong-argument bug.
   - **Detection:** `grep -rnE "CancellationToken [a-zA-Z_]+( = default)?, " --include=*.cs .` — every hit that is not the final parameter is a violation.
9. **Simplify member access (IDE0002/IDE0001) — but verify the binding first.** Inside the `DiGi` root, drop any namespace qualifier the compiler does not need; a `DiGi.` prefix on a type that already resolves is redundant noise.
   - **Correct** — in `namespace DiGi.GIS.PostgreSQL.UI.Classes`, `Serilog` resolves up the enclosing chain to `DiGi.Serilog`:
     ```csharp
     Serilog.Modify.Log(Serilog.Enums.LogEventLevel.Error, "Import failed");
     ```
   - **The exception — innermost-namespace shadowing.** C# resolves the FIRST segment against each enclosing namespace from innermost outwards, and once it binds there is **no fallback**. From `DiGi.GIS.PostgreSQL.UI.Classes`, `WebAPI` binds to `DiGi.GIS.WebAPI` (not `DiGi.WebAPI`), so the qualifier must stay:
     ```csharp
     postResponse = await DiGi.WebAPI.Query.GetAsync<Building>(httpClient, requestUri, postOptions);
     ```
     The same trap applies to `Core`, `Geometry`, `Analytical` and any other segment that repeats at several depths.
   - **Method:** remove the qualifier, then **rebuild**. A shadowed name usually fails with CS0234/CS0246 — restore the prefix and leave a short comment saying why. Never shorten a qualifier you have not compiled. If BOTH namespaces expose a matching member, the shortened form compiles and silently calls the wrong one — keep the qualifier regardless of the analyzer suggestion.
10. **Project Structure:** Assume the C# codebase consists of multiple SEPARATE projects, not a single monolithic solution. Handle namespaces and references accordingly.
11. **Output Optimization:** Prioritize highest code quality and output token minimization. Skip conversational filler, polite introductions, and conclusions. Output only the necessary code, logic, or requested explanations.

---

### 2. Architecture & Project Structure (DiGi.Core Pattern)
Data models are strictly separated from business logic (anemic models + static extension methods). Follow this structure for all new features.

**Data models:**
- **Classes** → `/Classes`, ns `[Project].Classes` — lightweight (properties + basic constructors only), **no** complex logic.
- **Interfaces** → `/Interfaces`, ns `[Project].Interfaces`.
- **Enums** → `/Enums`, ns `[Project].Enums`.

**Business logic** — all complex behavior is an extension method in one of static partial classes; never create a manager/service class:
- **`Query`** (`/Query`) — returns a result from a query; does NOT modify the source (e.g. translating dynamic filter groups into SQL/parameterized commands).
- **`Modify`** (`/Modify`) — modifies the state/properties of the existing object.
- **`Create`** (`/Create`) — creates and returns a completely new object from input data.
- **`Convert`** (`/Convert`, subdirs `/Convert/To[TargetArea]` e.g. `/Convert/ToSystem`, `/Convert/ToEPW`, `/Convert/ToDiGi`) — converts/formats/transforms an object or raw components into another representation; method names follow `To[TargetArea]_[TargetType]` (`ToSystem_String`, `ToSystem_DateTime`, `ToEPW_DateTime`).

### Exception — interface-contract members are implemented ON the class
The anemic-model + static-extension rule governs behavior that is **not** part of an interface the `/Classes` type implements. When a method is declared on an interface the class implements, it MUST be a normal **instance method on that class** — C# offers no other way to satisfy the contract, and moving it to a `Query`/`Modify` extension leaves the interface unimplemented (CS0535).

This is the deliberate design for **behavior-rich geometry primitives**. `DiGi.Geometry`'s `Ellipse2D`, `Circle2D`, `Segment2D`, `Polygon2D`, `Rectangle2D`, their spatial counterparts, etc. implement rich behavioral interfaces and therefore carry their behavior as instance methods — for example `IBoundable2D.GetBoundingBox()`, `ITransformable2D.Transform(...)`, `IMovable2D.Move(...)`, and `IClosedCurve2D.{GetInternalPoint, InRange, Inside, GetArea}`. These types are **not** anemic, and that is correct.

- **Do not "migrate" a geometry primitive's instance methods to `Query`/`Modify` extensions, and do not flag them as anemic-model violations.** Deleting a contract implementation breaks the interface and diverges from the entire library.
- **Before proposing to move or remove such a method, check the interface chain first** (the `I*2D` hierarchy under `Planar/Interfaces` / `Spatial/Interfaces`). Only behavior that is genuinely not a contract member — and that belongs to a data model rather than a geometry primitive — goes into the static partial classes.
- **Private helpers are allowed on such a class.** The "strictly avoid private methods" rule below is scoped to the static partial utility classes (`Query`/`Modify`/`Create`/`Convert`), not to `/Classes` types that implement behavioral interfaces.

### Method Encapsulation and Reusability in Utility Classes
- **Strictly avoid creating private methods** within `Query`, `Convert`, `Modify`, and similar partial utility classes.
- If a helper method has well-defined inputs, no side effects, and high reusability, implement it as a **public static method** within the appropriate partial class (e.g., `Query`, `Convert`, `Modify`).
- If a helper method is strictly single-use or specific to a narrow scope, implement it as a **local function (inline method)** directly inside the method you are currently implementing.

### Convert Class Pattern (conversion methods)
`public static partial class Convert` is the **first choice** for any method that transforms an object into another representation — including performance-oriented variants that avoid defensive cloning. Never implement a conversion as an instance method on a `/Classes` model; model classes stay anemic.

The pattern, as established across the `Convert` folders (reference: `DiGi.Geometry/Planar/Convert`):

- **Folder/file layout:** `/Convert/To[TargetArea]/[TargetType].cs` — one file per TARGET type, named after the target type; all source-type overloads converting to that target live in that file (e.g. `ToNTS/LinearRing.cs`, `ToDiGi/Polygon2D.cs`, `ToNTS/Coordinates.cs`).
- **Method shape:** `public static` **extension method on the SOURCE type**; reference-type parameters are nullable; return `null` for null/invalid input instead of throwing.
- **Naming:** plain `To[TargetArea](...)` when the source type has a single natural target in that area — the target is then distinguished by the source overload (`ToNTS(this Point2D?)` → `Coordinate`, `ToNTS(this Segment2D?)` → `LineSegment`, `ToNTS(this IPolygonal2D?)` → `LinearRing`). Use the suffixed form `To[TargetArea]_[TargetType](...)` when the same source converts to several targets in one area (`ToNTS_LineString(this Segment2D?)` and `ToNTS_Polygon(this IPolygonal2D?)` beside the plain overloads above; `ToDiGi_Polygon2Ds(this Polygon?)` beside `ToDiGi(this Polygon?)` → `PolygonalFace2D`).

### Naming Conventions for Query Partial Class
- Enforce a property-like naming convention for methods inside the `Query` class.
- **Do not use verbs as prefixes** (e.g., avoid `Get`, `Find`, `Calculate`).
  - *Example:* `GetBoundingBox()` must be named `BoundingBox()`.
- **Exceptions:** Verbs indicating boolean checks or safe-retrieval patterns are required. Allowed prefixes are `Is`, `Has`, and `Try`.
  - *Examples:* `IsPlanar()`, `HasMaterial()`, `TryConvert()`.

## Project assets — `files/` vs `user files/` (NEVER commit secrets)
Runtime assets a project copies to its output belong in one of two solution-root folders, chosen by
sensitivity. **Secrets, credentials and machine-specific configuration MUST go in `user files/`,
never in `files/`.** Both are copied to the build output by a `.csproj` target; the difference is git.

- **`files/`** — committed to source control. Non-sensitive, environment-agnostic deployment assets
  shared by everyone (e.g. `web.config`, `app_offline.htm.bak`). Copied by a `CopyFiles` target:
  ```xml
  <Target Name="CopyFiles" AfterTargets="Build">
    <ItemGroup>
      <_Files Include="$(ProjectDir)..\files\**\*.*" />
    </ItemGroup>
    <Copy SourceFiles="@(_Files)" DestinationFiles="@(_Files->'$(OutputPath)%(RecursiveDir)%(Filename)%(Extension)')" SkipUnchangedFiles="true" />
  </Target>
  ```
- **`user files/`** — git-**ignored**. Fragile / user-specific / secret data: database connection
  configs (`*.conf` with host/user/password), API keys, local paths, per-machine settings. Copied by
  a `CopyUserFiles` target with the identical shape but `..\user files\**\*.*`. The consuming code
  reads these from next to the executing assembly at runtime, so the app works locally and on the
  server without the secrets ever entering the repo.

**Enforcement:** the solution-root `.gitignore` must contain the case-insensitive rule
`[Uu]ser [Ff]iles/`. Verify with `git check-ignore -v "user files/<file>"` — git must report the rule
as the reason the file is ignored. If a new solution needs runtime secrets and lacks this rule, add
it before dropping any secret in. Reference implementations: `DiGi.GIS.PostgreSQL.UI`,
`DiGi.GIS.PostgreSQL.WebAPI` (both hold `GIS_PostgreSQL_Main.conf` in an ignored `user files/`).

**Decision rule when placing a runtime asset:** would committing it leak a secret, or break another
developer's / the server's machine-specific setup? If yes → `user files/`; otherwise → `files/`.

- **Script configurations (PowerShell)**: PowerShell scripts requiring machine-specific, secret, or environment-specific paths (e.g., local backup paths or cloud storage directories) must load these settings from a `.conf` file inside the `user files/` directory, rather than hardcoding them in the scripts or introducing custom `.gitignore` records.

---

### 3. Reference Comparison (`IReference` / `IUniqueReference`)

> **Never compare two interface-typed references with `==` or `!=`. Use `Core.Query.Equals(reference_1, reference_2)`.**

This is not a style preference. `==` between two interface-typed operands compiles to **reference equality**, silently returns `false` for two equal references, and the compiler emits no warning. It has already produced an infinite loop in `BuildingModelShellUpdater` and mis-attributed geometry in `ShellByPlaneSplitSolver`.

**Why the operators do not apply.** For `a == b`, C# gathers user-defined operator candidates from the **static types of the operands and their base classes** — an interface contributes none. The `==`/`!=` operators live on `SerializableReference`, so the comparison is correct as soon as **one** side is a concrete `SerializableReference`-derived type (or the `null` literal).

| Static type of the operands | What `==` compiles to | Verdict |
|---|---|---|
| both interfaces (`IReference`, `IUniqueReference`, `ISerializableReference`, …) | predefined reference equality | **silent bug** |
| at least one `SerializableReference`-derived (`GuidReference`, `TypeReference`, …) | `SerializableReference.operator ==` → `Equals` | correct |
| one side is the `null` literal | null check | correct |
| `.ToString()` on both sides | string comparison | correct, but allocates |

This cannot be fixed by adding operators: interfaces contribute no operator candidates, a `operator ==(IReference, IReference)` declared in a helper class is **CS0563**, and C# 11 static abstract interface operators dispatch only through a constrained generic type parameter (and require net7.0+, while `DiGi.Core` targets `netstandard2.0`).

**The compounding trap — clone-per-call accessors.** Many model properties return `Core.Query.Clone(field)` and therefore hand back a **new instance on every read**, so `face.UniqueReference == face.UniqueReference` is `false` — the same face compared with itself. Read the property into a local before using it; never call it inside a predicate that runs per element (it is also an allocation per iteration).

| Intent | Use |
|---|---|
| Are these two references the same reference? | `Core.Query.Equals(reference_1, reference_2)` (null-safe, two nulls are equal) |
| Look up / group / de-duplicate | `Dictionary`, `HashSet`, `List.Find`/`FindAll`/`FindIndex`/`Contains` — already correct, they route through `Equals`/`GetHashCode` |
| I need the concrete API | pattern-match: `if (uniqueReference is GuidReference guidReference)` |
| Is this the same *instance* of a model object? | compare its `Guid` — a reference identifies the referenced object, not the object holding it |

```csharp
// WRONG - both operands are IUniqueReference, this is reference equality and never matches
int index = faces.FindIndex(x => x.UniqueReference == face.UniqueReference);
```

```csharp
// CORRECT - hoist the clone-returning accessor into a local, then compare by value
IUniqueReference? uniqueReference = face.UniqueReference;

int index = faces.FindIndex(x => Core.Query.Equals(x?.UniqueReference, uniqueReference));
```

**Do not assume an `IReference` is a `SerializableReference` — never cast to it.** `ListClusterReference<TKey_1, TKey_2>` implements `IReference` directly, and `IUniqueReference` has two class branches (`UniqueReference` and `UniqueExternalReference<T>`) with no common base below `SerializableReference`.

---

### 4. XML Documentation Standards
All public constructors, properties, methods, and enum values must be fully documented using XML comments:
* **Code preservation & sync:** Edit only `///` comments — never change C# logic. Add missing tags, and rewrite any existing comment that is outdated, inaccurate, or describes logic/parameters that no longer exist.
* **Explicit typing:** No `var` in any code snippet you touch.
* **Partial classes:** Don't document the class declaration itself when marked `partial`; document only its members.
* **Exhaustive coverage:** Every public member must have an accurate, up-to-date description.
* **Quality over speed** — prioritize accuracy and alignment with the code's actual behavior.
* **Reference context:** For each referenced library, ingest its sibling XML doc file (`LibraryName.dll` → `LibraryName.xml`, same directory) for accurate cross-referencing, terminology, and external type/parameter descriptions.
* **Signature matching:** Docs must match signatures exactly — remove `<param>` tags for parameters that no longer exist, add tags for new ones. Document all `<param>`, `<returns>`, and `<typeparam>` to avoid CS1591/CS1573.
* **Single summary:** Exactly one `<summary>` per element. When updating, overwrite the old one — never append. Do a final pass to strip any redundant tags.
* **No empty lines** inside doc blocks (no blank line or bare `///`) — they break Visual Studio IntelliSense tooltip rendering. Use `<para>` for paragraph breaks:

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

---

### 5. API Reference Documentation Locating
To minimize token consumption and avoid parsing full implementation files, you MUST consult the generated Markdown documentation first when exploring type schemas, namespaces, and public API interfaces:
To save tokens, consult the generated Markdown API docs before parsing `.cs` source when exploring type schemas, namespaces, or public API.

- **Path:** `documentation/API/[AssemblyName]/` in each active workspace — one directory per assembly, split by **namespace** (e.g. `DiGi.Core.Classes.md`). These files hold exact signatures and `<summary>` descriptions for all public classes, constructors, methods, properties, and enums.
- **Fallback:** if `documentation/API/` is absent, scan the C# source and `/bin/*.xml` files.

---

### 6. Serialization Pattern (SerializableObject / ISerializableObject)
Classes under `/Classes` needing JSON persistence, cloning, or polymorphic deserialization MUST inherit `DiGi.Core.Classes.SerializableObject` in this exact shape (reflection-driven — no manual JSON parsing).

1. **Marker interfaces** per project under `/Interfaces` (mirroring `DiGi.GIS.Interfaces.IGISObject`/`IGISSerializableObject`):
   ```csharp
   // /Interfaces/I<Project>Object.cs
   public interface I<Project>Object : DiGi.Core.Interfaces.IObject
   {
   }

   // /Interfaces/I<Project>SerializableObject.cs
   public interface I<Project>SerializableObject : I<Project>Object, DiGi.Core.Interfaces.ISerializableObject
   {
   }
   ```
   Every serializable class implements `I<Project>SerializableObject` (e.g. `public class Holiday : SerializableObject, IEPWSerializableObject`).
2. **Fields:** `private readonly`, each `[JsonInclude, JsonPropertyName(nameof(PublicPropertyName))]` — always `nameof(...)`, never a hardcoded string literal.
3. **Three constructors, always in this order:**
   - **Primary** (plain params, assigns fields) — no `base(...)` call needed.
   - **Copy** `ClassName(ClassName? classNameInstance) : base(classNameInstance)`, copying every field:
     - Primitive/value-type fields and strings: copy by value.
     - `List<T>`/`IList<T>` of **primitives**: `new List<T>(source)` (or `null` if source is `null`).
     - `IList<T>` of **nested `SerializableObject`-derived items**: clone element-by-element filtering nulls (see the excerpt below). Do NOT pipe the `IEnumerable<T>.Clone<T>()` extension into an `IList<T>` field — it returns `List<T?>?`, a nullable-element mismatch against a non-nullable `IList<T>` field.
     - A single nested `SerializableObject` reference: `field = Core.Query.Clone(source.field);`.
   - **JSON** `ClassName(JsonObject? jsonObject) : base(jsonObject)` — pure delegation, empty body.
4. **Properties:** `[JsonIgnore]` get-only, returning the backing field (the field attribute handles serialization — do not also serialize through the property).
5. **Project file:** `.csproj` needs a `<Reference Include="DiGi.Core"><HintPath>..\..\DiGi.Core\bin\DiGi.Core.dll</HintPath></Reference>` and a `<PackageReference Include="System.Text.Json" .../>` matching the version used elsewhere (check `DiGi.Core.csproj`).

### Example — simple class with primitive fields (`/Classes/Holiday.cs`)
```csharp
using DiGi.Core.Classes;
using DiGi.EPW.Interfaces;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace DiGi.EPW.Classes
{
    public class Holiday : SerializableObject, IEPWSerializableObject
    {
        [JsonInclude, JsonPropertyName(nameof(Name))]
        private readonly string? name;

        [JsonInclude, JsonPropertyName(nameof(Date))]
        private readonly string? date;

        public Holiday(string? name, string? date)
        {
            this.name = name;
            this.date = date;
        }

        public Holiday(Holiday? holiday)
            : base(holiday)
        {
            if (holiday != null)
            {
                name = holiday.name;
                date = holiday.date;
            }
        }

        public Holiday(JsonObject? jsonObject)
            : base(jsonObject)
        {
        }

        [JsonIgnore]
        public string? Name
        {
            get
            {
                return name;
            }
        }

        [JsonIgnore]
        public string? Date
        {
            get
            {
                return date;
            }
        }
    }
}
```

### Example — nested list of `SerializableObject` items (copy-constructor excerpt)
```csharp
public HolidaysDaylightSaving(HolidaysDaylightSaving? holidaysDaylightSaving)
    : base(holidaysDaylightSaving)
{
    if (holidaysDaylightSaving != null)
    {
        leapYearObserved = holidaysDaylightSaving.leapYearObserved;

        if (holidaysDaylightSaving.holidays != null)
        {
            holidays = [];
            foreach (Holiday holiday in holidaysDaylightSaving.holidays)
            {
                if (Core.Query.Clone(holiday) is Holiday holiday_Temp)
                {
                    holidays.Add(holiday_Temp);
                }
            }
        }
    }
}
```

### Example — `List<double>` of primitives (copy-constructor excerpt)
```csharp
public GroundTemperature(GroundTemperature? groundTemperature)
    : base(groundTemperature)
{
    if (groundTemperature != null)
    {
        depth = groundTemperature.depth;
        monthlyValues = groundTemperature.monthlyValues == null ? null : new List<double>(groundTemperature.monthlyValues);
    }
}
```

---

### 7. Automatic Tests (xUnit)
1. **One test project per project:** `[ProjectName].xUnit` (e.g. `DiGi.Core.xUnit`, `DiGi.Geometry.xUnit`).
2. **`public partial class Facts`** holds all test methods (one shared class per namespace).
3. **Files under `/Facts`.**
4. **Namespace matches the test project** (e.g. `namespace DiGi.Core.xUnit`).
5. **`Xunit` is global-usinged** by project config — do NOT add `using Xunit;`.
6. **`[Fact]`** marks test methods.
7. **Name the method** after the class/property/method under test (`Color()`, `PlanarIntersectionResult_Performance()`).
8. **XML `<summary>` on every test** describing what is tested — no empty lines inside the block (they break VS tooltips); use `<para>` for paragraph breaks.

#### 📂 Shared Test Data Files (Fixtures)
When a test needs an on-disk input file (`.gmf`, `.json`, `.epw`, …), use the **one shared `files` directory** — do NOT add a per-project data folder.

1. **Location:** `DiGi.Test/files/` (the `DiGi.Test` repo sits beside the other `DiGi.*` repos under the `DigiProject` workspace root; from a `DiGi.Test/<ProjectName>.xUnit/` dir it is `../files/`). The path is given relative to the workspace root because this guideline lives in the separate `DiGi.Maintenance` repo.
2. **Add a fixture:** drop the file into `DiGi.Test/files/` and reference it by file name only. Files are read **in place** (not copied to build output) — no `<None CopyToOutputDirectory>` entry needed.
3. **Resolve the path:** `Core.xUnit.Query.FilePath(System.Reflection.Assembly.GetExecutingAssembly(), "<fileName>")` returns the absolute path to `DiGi.Test/files/<fileName>`; for the directory itself use `assembly.FilesDirectory()`. Both live in `DiGi.Core.xUnit/Query/` (`FilePath.cs`, `FilesDirectory.cs`) and resolve by walking up from the test assembly's `bin/<ProjectName>.xUnit/` output. `FilePath` `Assert`s the directory resolves, so a `null`/missing result fails the test cleanly.
4. **No `using` needed** — call it fully qualified as `Core.xUnit.Query.FilePath(...)`; it resolves via the same innermost-enclosing-namespace lookup as `Core.xUnit.Query.SerializationCheck(...)`, as long as the test namespace nests under `DiGi`. Add `using System.Reflection;` (or fully qualify `Assembly`).
5. **Example:**
   ```csharp
   using System.Reflection;
   // ...
   string? path = Core.xUnit.Query.FilePath(Assembly.GetExecutingAssembly(), "0207_GML.gmf");
   Assert.False(string.IsNullOrWhiteSpace(path));
   Assert.True(System.IO.File.Exists(path));
   ```
   References: `DiGi.GIS.xUnit/Facts/OrtoDatas.cs`, `DiGi.EPW.xUnit/Facts/EPWFile.cs`, `DiGi.Geometry.xUnit/Facts/InRange.cs`.
6. **Large binaries** (multi-MB `.gmf`, etc.) are git-tracked (not ignored) — prefer a representative-but-minimal sample, and consider Git LFS if size becomes a concern.

---

### 8. Branch Synchronization & Versioning Protocol
1. **Version branch only:** run only when the active branch is a bare SemVer `*.*.*` (e.g. `0.8.2`, `1.12.0`). Skip anything with text, prefix, or suffix (`feature/login`, `v0.8.2`, `0.8.2-beta`, `main`).
2. **Differs from main:** run only for repos where the active branch differs from `main`; skip repos where they are identical.

#### 🔄 Synchronization Workflow (Execution Steps)
1. **Sync with main:** merge the version branch into `main` so both hold the exact same codebase, with no pending diffs.
2. **Bump patch:** increment the third version digit by 1 (`0.8.2` → `0.8.3`).
3. **Branch off main** using that new version name.
4. **Update `Directory.Build.props`** (if present): set `<Major>`/`<Minor>`/`<Build>` to the new version's components and commit on the new branch before pushing.
5. **Push & track:** push both `main` and the new version branch to `origin`, using `-u` on the new branch so it tracks properly (`git push -u origin <version_branch>`).
