# AI Guidelines: C# General Coding Standards & Architecture

**Environment:** Visual Studio 2026 / Windows 11 / .NET 9.0+ / C# 10+.  
**Domain:** C# plugins & engineering software (Revit API, RhinoCommon, Grasshopper, Dynamo).

---

## 1. Core Coding Rules

1. **Language:** **English only** for identifiers, comments, and documentation.
2. **Explicit Typing (No `var`):** Mandatory explicit variable typing unless compiler-forced (e.g. anonymous types).
   - Use target-typed `new()`: `PointNode pointNode = new();`
   - Use collection expressions `[]`: `List<int> numbers = [];`, `int[] array = [1, 2, 3];`
3. **Variable Naming:**
   - **Standard:** `camelCase` starting with type name (`PointNode pointNode`). Add `_`-suffixed qualifier when needed (`PointNode pointNode_Base`, `pointNode_Temp`).
   - **Collections:** Use pluralized element type name — do not prefix with collection type (`filterConditions`, `point3Ds`; not `conditions`, `listPoints`).
   - **Descriptive Value Types:** Name property after type if unique (`public AggregateFunction AggregateFunction { get; set; }`).
   - **Primitives:** Plain `camelCase` (`double tolerance`, `string name`, `int count`).
4. **Compiler Warnings:** **Zero warnings/analyzer messages allowed.** Handle nullability and validation cleanly.
5. **Block-Scoped Namespaces:** Enforce block-scoped `namespace DiGi.Domain { ... }`. Prohibit file-scoped namespaces (`csharp_style_namespace_declarations = block_scoped`).
6. **Parameter Line Breaks (`<= 7` Rule):**
   - **<= 7 parameters:** Must remain on a **single line**, however long that line becomes.
   - **>= 8 parameters:** Split parameters onto multiple lines, **strictly one parameter per line** (multiple parameters on the same line violate `DIGI0001`).
   - **Scope:** Applies strictly to **parameter declarations** on methods, constructors, local functions, and delegates (enforced via analyzer `DIGI0001`).
   - **Call Sites (`ArgumentList`):** Single-line formatting is standard and preferred for simple argument lists. Multi-line formatting (one argument per line or aligned) is permitted when arguments are complex expressions, multi-line lambdas (`x => { ... }`), object/collection initializers, or when line breaking improves readability.
   - A long signature is not a reason to wrap. Line length is not the trigger — the parameter count
     is, because a signature that reads as one line stays greppable and diffs as one line. A WebAPI
     action binding six query parameters plus a `CancellationToken` is exactly the shape this rule
     protects: wrapping it turns a one-line diff into seven.
7. **Async Naming:** All asynchronous method names must end with `Async` (e.g., `GetDetailsAsync`).
8. **`CancellationToken` Rules (CA1068):**
   - **Position:** `CancellationToken` must ALWAYS be the **LAST parameter** in every method signature and overload.
   - **Optional Parameters:** Insert new parameters *before* the token, never after.
   - **XML Documentation:** Order `<param>` tags to mirror signature order exactly.
   - **Call Sites:** Pass by name: `cancellationToken: cancellationToken`.
   - **Overload Ambiguity:** Prevent CS0121 when reordering by using named arguments for differing parameters.
   - **Detection:** `grep -rnE "CancellationToken [a-zA-Z_]+( = default)?, " --include=*.cs .` (hits prior to last parameter are violations).
9. **Simplify Member Access & Shadowing (IDE0002/IDE0001):**
   - Omit redundant `DiGi.` namespace prefixes when types resolve unambiguously.
   - **Innermost-Namespace Shadowing Exception:** Keep full prefix when a parent namespace shares a segment name with an inner namespace (e.g., `DiGi.WebAPI.Query` vs `DiGi.GIS.WebAPI`). Always rebuild after removing a prefix; keep qualifier if CS0234/CS0246 occurs or if both namespaces contain matching types.
10. **Project Structure:** Treat codebase as multiple SEPARATE projects, not a monolithic solution.
11. **Output Efficiency:** Direct, technical responses. Omit conversational filler.
12. **Temporary Code Markers (`TODO [MarkerName]`):** Code that exists only until a migration completes must say so at every site, in a form one `grep` can collect.
   - **Tag:** `TODO [MarkerName]:` where `MarkerName` is PascalCase and names the **migration**, not the issue (`[ReferenceFormat]`, `[ReferencedObjectIndexes]`). Reuse the one tag at every site belonging to that migration, so `grep -rn "MarkerName"` returns the complete deletion checklist rather than a sample of it.
   - **State the removal condition** — the observable fact that makes deletion safe ("once every storage archive has been rewritten", "once every deployed database has run this DDL at least once"), not merely that the code is temporary. A marker without one cannot be acted on and never gets removed. Name the tracking issue when there is one.
   - **Placement:** an inline comment at the site; a file header above the `using` block when the whole file is temporary (`DiGi.Core/Query/TryParseLegacy.cs`); `[TEMPORARY]` as the first token of the XML `<summary>` when a whole public member is provisional and removing it is a public-API change (`DiGi.GIS.WebAPI.UI/Controllers/SolarController.cs`).
   - **A workaround for a defect in another DiGi repository is temporary code too.** Name the marker after the workaround, and make the removal condition the upstream fix, naming its issue. `DiGi.GIS.WebAPI.UI`'s `TerrainCuttingMaxBuildingCount = 250` silently skipped terrain footprint cutting above 250 buildings to dodge a `DiGi.Geometry` crash. It said *"Temporary limitation ... until spatial batching optimization is implemented"* in prose but carried no grep-able tag, so no sweep could collect it; it outlived its cause and was found only by reading the call site while investigating something else. Correct form: `TODO [TerrainCuttingCap]: remove once ZiolkowskiJakub/DiGi.Geometry#2 ships the triangulator fix.`
   - **Mark only what is actually temporary.** Permanent code shipped in the same change must not carry the tag, or the sweep stops being a checklist.

---

## 2. Architecture — `DiGi.Core` Pattern

Strictly separate data models from business logic using anemic models + static extension methods.

### Structure Breakdown
- **Models (`/Classes`):** Namespace `[Project].Classes`. Lightweight data containers (properties + basic constructors only). **No business logic.**
- **Interfaces (`/Interfaces`):** Namespace `[Project].Interfaces`.
- **Enums (`/Enums`):** Namespace `[Project].Enums`.
- **Business Logic:** Static partial classes providing extension methods. Never create service/manager classes.
  - `Query` (`/Query`): Returns query results. **Does NOT modify source.**
  - `Modify` (`/Modify`): Modifies state/properties of target object in-place.
  - `Create` (`/Create`): Instantiates and returns new objects.
  - `Convert` (`/Convert/To[TargetArea]`): Transforms objects/primitives into target representations (`ToSystem_String`, `ToEPW_DateTime`).

### Interface Contract Exception (Geometry Primitives)
- Methods required by an interface implemented by a `/Classes` type MUST be implemented as **instance methods on the class** (e.g., `Ellipse2D`, `Circle2D`, `Polygon2D` implementing `IBoundable2D`, `ITransformable2D`, `IMovable2D`, `IClosedCurve2D`).
- **Do NOT migrate interface contract methods to `Query`/`Modify` extensions.**
- Check interface hierarchy before proposing method relocations.
- Private helper methods are permitted on interface-implementing geometry model classes.

### Constructors Stay Cheap — Put Calculation in `Create`

- **Constructors on `/Classes` types assign and clone. Nothing else.** No validation sweep, no
  normalisation, no cleanup pass, no geometric or numeric computation — not even an `O(n)` scan over
  a collection the caller just handed over. A constructor is on the hot path of every clone, every
  copy constructor and every deserialization, and a caller who already holds clean data must not pay
  for a check they do not need.
- **Any such work belongs in a `Create` factory** named after the type it returns, at
  `/Create/[TypeName].cs`. The factory does the work, then calls the plain constructor. It returns
  the type as **nullable** and returns `null` when the input cannot make a valid object, so the
  guard is a return value rather than an exception.
- **Order inside the factory:** materialise and filter the input, run the cleanup, *then* check the
  result is still valid. Validating before the cleanup measures the wrong thing — a ring of three
  positions that repeats a corner passes a "three or more" check and then becomes a two corner
  polygon.
- **Document the split on both sides.** The constructor's `<summary>` points at the factory for
  callers whose data is not already clean; the factory's `<summary>` says what it removes and why
  the constructor does not.

**Reference:** `DiGi.Geometry.Spatial.Create.Polygon3D(IEnumerable<Point3D?>?, double)` and
`DiGi.Geometry.Planar.Create.Polygon2D(IEnumerable<Point2D?>?, double)` — both drop points repeating
their predecessor via `Modify.RemoveDuplicates(..., closed, tolerance)` before checking the corner
count, while `Polygon2D`'s constructors store whatever they are given.

```csharp
// /Classes — plain assignment, no work
public Polygon2D(IEnumerable<Point2D>? point2Ds)
    : base(point2Ds)
{
}

// /Create — the work lives here, and the guard runs after it
public static Polygon2D? Polygon2D(this IEnumerable<Point2D?>? point2Ds, double tolerance = DiGi.Core.Constants.Tolerance.Distance)
{
    if (point2Ds == null)
    {
        return null;
    }

    List<Point2D> point2Ds_Temp = [];
    foreach (Point2D? point2D in point2Ds)
    {
        if (point2D != null)
        {
            point2Ds_Temp.Add(point2D);
        }
    }

    point2Ds_Temp.RemoveDuplicates(true, tolerance);

    if (point2Ds_Temp.Count < 3)
    {
        return null;
    }

    return new Polygon2D(point2Ds_Temp);
}
```

### File Organisation — One Member Per File

- **`Query`/`Modify`/`Create` — one method per file, named after the method.** A file in `/Query`,
  `/Modify` or `/Create` holds exactly one public method, and the file name is that method's name
  (`/Spatial/Query/NearestIndexes.cs` holds `NearestIndexes`). Do **not** group related methods into
  one file: `TryGetNearestIndexes`, `NearestIndexes` and `NearestNeighbors` are three files, not one.
  - **Overloads are the same method and stay together.** Every `Triangle3D(...)` overload lives in
    `Triangle3D.cs`; the plural `Triangle3Ds(...)` is a different method name and gets
    `Triangle3Ds.cs`.
  - Helpers promoted to `public static` under the encapsulation rule below get their own file too,
    named after the helper.
  - `Convert` keeps its own layout, `/Convert/To[TargetArea]/[TargetType].cs` — file per TARGET
    type, not per method, so all conversions to one target share a file.
- **Nested types get their own file, `[Outer].[Inner].cs`.** A `class`, `struct`, `record` or `enum`
  declared inside another type is moved to its own file next to the outer type's file, declaring the
  outer type `partial` and carrying only the nested type — `/Spatial/Classes/PointCloud3D.Point.cs`
  and `/Spatial/Classes/PointCloud3D.Enumerator.cs` sit beside `/Spatial/Classes/PointCloud3D.cs`.
  Keep the type nested; do not promote it to a top-level type, because that changes the public API
  and usually the name stops making sense on its own (`Point`, `Enumerator`).
  - The outer `partial` declaration is repeated in each file with no XML `<summary>` on it, per the
    "do not document `partial` class declarations" rule.

### Method Encapsulation in Utility Classes (`Query`/`Modify`/`Create`/`Convert`)
- **Prohibit `private static` methods** inside partial utility classes.
- **Reusable helpers:** Implement as `public static` methods within the appropriate partial class.
- **Single-use helpers:** Implement as **local functions (inline methods)** inside the consuming method body.

### `Convert` Class Rules
- File layout: `/Convert/To[TargetArea]/[TargetType].cs`.
- Method shape: `public static` extension method on source type. Return `null` for null/invalid input (do not throw).
- Method naming: `To[TargetArea](this SourceType?)` for single target; `To[TargetArea]_[TargetType](this SourceType?)` when multiple targets exist for a single source.

### `Query` Naming Conventions
- Use property-like names without verb prefixes (e.g., `BoundingBox()`, NOT `GetBoundingBox()`).
- **Allowed verb prefixes:** Only `Is`, `Has`, and `Try` (e.g., `IsPlanar()`, `HasMaterial()`, `TryConvert()`).

### Result Type Naming — `IResult` Implementations End in `Result`
- **Any class implementing `IResult` / `ISerializableResult` (in practice, anything deriving from `SerializableResult` or `UniqueResult`) MUST have a name ending in `Result`.** `TerrainPointDensityResult`, not `TerrainPointDensity`; `TerrainPointCoverageResult`, not `TerrainPointCoverage`.
- **Do not stack a second noun for the same idea.** The suffix already says the type reports an outcome, so drop `Summary`, `Report`, `Info`, `Data` and the like rather than keeping both: `TerrainPointCountyResult`, NOT `TerrainPointCountySummaryResult` and NOT `TerrainPointCountySummary`.
- **The `Create` factory is named after the type it returns**, so it takes the suffix too — `Create.TerrainPointDensityResult(...)` in `/Create/TerrainPointDensityResult.cs`, per [File Organisation](#file-organisation--one-member-per-file).
- **Why it matters beyond consistency:** the JSON `_type` discriminator carries the class name, so the name is part of the wire contract. Getting it right at creation is free; changing it afterwards breaks every stored document and every deployed client.
- **Existing violations are NOT to be renamed opportunistically.** `Building2DReferenceUniquenessSummary` and `Building2DReferenceDuplicate` (both `: SerializableResult`, both served by deployed `Building2DController` endpoints) predate this rule. Renaming them is a breaking wire change and needs its own decision, migration and version bump — not a drive-by fix. The rule governs new types.

### Standard Tolerance Constants (`DiGi.Core.Constants.Tolerance.*`)
Never introduce arbitrary magic numbers (e.g. `0.001`, `1e-5`, `0.00001`) when invoking or implementing geometric, spatial, or mathematical calculation routines requiring a tolerance parameter. Always reference canonical constants defined in `DiGi.Core.Constants.Tolerance`:
- `Tolerance.Distance` (`1e-6`): Primary spatial/distance tolerance for point proximity, segment/polygon intersection, vertex deduplication, and bounding box overlap checks.
- `Tolerance.Angle`: Angular tolerance for vector parallelism, orthogonality, and angle comparisons.
- `Tolerance.General` / `Tolerance.Macro`: Macro-level numeric comparison tolerances.

---

## 3. Solution Assets — `files/` vs `user files/`

- **`files/` (Committed):** Non-sensitive, shared deployment assets (`web.config`, `app_offline.htm.bak`). Copied to build output via `CopyFiles` MSBuild target.
- **`user files/` (Git-Ignored):** Sensitive, user-specific, local machine data (DB credentials `*.conf`, API keys, local paths), and test report outputs (`user files/reports/`). Copied via `CopyUserFiles` target.
  - Solution `.gitignore` MUST contain `[Uu]ser [Ff]iles/`. Verify with `git check-ignore -v "user files/file.conf"`.
  - PowerShell scripts requiring environment paths MUST read `.conf` files from `user files/`.
  - Automated test reports, diagnostic dumps, and text logs produced during test execution MUST be saved to `user files/reports/` (resolved via `assembly.ReportsDirectory()`).
- **Solution Items (`.sln` / `.slnx`):** In Visual Studio 2026 solutions, root-level configuration and build assets must be organized under the `Solution Items` virtual folder:
  - `Directory.Build.props`
  - `Directory.Build.targets`
  - `.editorconfig`
  - `DefaultDocumentation.json` (if present)

---

## 4. Host Dependencies — `HintPath` Drops Transitive NuGet Packages

DiGi projects reference each other with `<Reference><HintPath>..\..\X\bin\X.dll</HintPath>`, never
`<ProjectReference>`. A raw assembly reference is **opaque to NuGet**, and the DiGi class libraries do
not copy their own NuGet dependencies into their `bin`. A library's third-party dependencies therefore
never reach a host that consumes it by `HintPath`.

### Before Adding One — Check What You Already Reference
The cheapest package is the one you do not add. Because of the rule below, every new dependency has to be
re-declared on every deployed host at the same version, so spending a few minutes enumerating the packages
already in the tree is always the better trade. A package is usually far larger than the slice of it
currently in use.

- **Read the package's own XML docs.** Every NuGet package ships them beside the DLL, in the NuGet global
  package folder (`%USERPROFILE%\.nuget\packages\`) under `<id>/<version>/lib/<tfm>/<Id>.xml`. Grep it by
  namespace — it lists every public type with its `<summary>`, which is faster and more complete than a web
  search. Reflect over the assembly (`Assembly.GetExportedTypes()`) for the bare type list, or byte-scan the
  DLL for a type name when reflection-only loading is unavailable on the platform.
- **Check the target framework the consuming project actually builds for.** `DiGi.Geometry` is
  `netstandard2.0`; a type found in a package's `netstandard2.1` folder is not automatically present in the
  `netstandard2.0` one. Verify against the right `lib/<tfm>/` folder before designing around it.
- **Worked example.** [DiGi.Geometry#2](https://github.com/ZiolkowskiJakub/DiGi.Geometry/issues/2) carried
  two proposals: add `Clipper2` + `Cutear`, or hand-write ~200 lines of ear clipping with hole bridging.
  Both were for a triangulator that keeps the polygon's own vertices and supports holes.
  `NetTopologySuite` 2.6.0 — already referenced — ships exactly that as
  `NetTopologySuite.Triangulate.Polygon.PolygonTriangulator` and `PolygonHoleJoiner`, in both TFM folders.
  Zero packages added, and this section never had to be applied.
- **NetTopologySuite corollary, because it has cost time twice.**
  `NetTopologySuite.Triangulate.ConformingDelaunayTriangulationBuilder` is **not** the general polygon
  triangulator. It inserts Steiner points of its own and throws `ConstraintEnforcementException` when
  constraint splitting fails to converge, which narrow slivers reliably cause. Use
  `NetTopologySuite.Triangulate.Polygon.PolygonTriangulator` (ear clipping, holes joined onto the shell) or
  `ConstrainedDelaunayTriangulator` when triangle quality matters.

### The Rule
- When a `HintPath`-referenced DiGi library needs a NuGet package, re-declare that `PackageReference`
  on the **deployed host** (the `Exe`/`WinExe`/`Microsoft.NET.Sdk.Web` project), at the **exact same
  version**. Add a comment naming the library that owns the dependency.
- The chain runs deeper than the direct reference: `DiGi.Geometry` → `DiGi.Math` → `MathNet.Numerics`.
  Audit the whole closure, not just the assemblies listed in the `.csproj`.
- Do **NOT** fix this with `CopyLocalLockFileAssemblies=true` on the netstandard2.0 library — it bloats
  its `bin` with `System.*` 4.3.0 shims.
- `<ProjectReference>` consumers (siblings, `.xUnit`, `.Rhino`) are unaffected; NuGet flows normally there.

### The Failure Signature — Read This Before Suspecting the Data
**A missing transitive dependency produces a partial result, not an error.** `FileNotFoundException` is
thrown per item deep inside a loop, so a batch run completes and reports success while silently
delivering less than it should. County 5 modelled **65 % of 33 687 buildings and reported success**; the
shortfall was found by sampling the database, not by any log entry.

> When a run completes but delivers less than it should, check the host's output directory for missing
> assemblies **before** investigating the data.

**A green build and a green test suite prove nothing.** `DiGi.Test/DiGi.GIS.Analytical.xUnit` re-declares
`QuikGraph` for exactly this reason, so the suite exercised the storey split successfully while the
shipped application could not.

### Extension Hosts Are One Probing Set
`DiGi.GIS.WebAPI`, `DiGi.GLTF.WebAPI`, `DiGi.Communication.WebAPI` and `DiGi.User.WebAPI` deploy into
`DiGi.WebAPI.WindowsService\bin\extensions\<name>` and are loaded into `AssemblyLoadContext.Default`
with cross-directory `AssemblyDependencyResolver`s. Audit the host output **together with** its
`extensions\*` folders, and declare shared dependencies once on `DiGi.WebAPI.WindowsService` — that is
already how `Microsoft.OpenApi` and `Serilog` reach the extensions.

### The Check
Run after building; it inspects compiled output, not project files.
```powershell
PowerShell -ExecutionPolicy Bypass -File ".\CheckHostDependencies.ps1"
PowerShell -NoProfile -ExecutionPolicy Bypass -File ".\BuildAll.ps1" -Configuration Release -CheckDependencies
```
It reads each output assembly's reference table with `System.Reflection.Metadata.PEReader` and reports
every reference that resolves neither inside the deployment unit nor in a shared framework. Reviewed
exceptions are declared per unit inside the script, each with a stated reason — an unexplained entry
there re-hides the exact class of bug the script exists to find.

---

## 5. Serialization Pattern (`SerializableObject` / `ISerializableObject`)

Classes requiring JSON persistence, cloning, or polymorphic deserialization MUST inherit `DiGi.Core.Classes.SerializableObject`.

### Class Requirements
1. **Marker Interfaces (`/Interfaces`):**
   - `public interface I<Project>Object : DiGi.Core.Interfaces.IObject`
   - `public interface I<Project>SerializableObject : I<Project>Object, DiGi.Core.Interfaces.ISerializableObject`
2. **Backing Fields:** `private readonly`, decorated with `[JsonInclude, JsonPropertyName(nameof(PublicPropertyName))]`.
3. **Three Constructors (Mandatory Order):**
   - **Primary:** `(param1, param2)` — sets backing fields.
   - **Copy:** `ClassName(ClassName? source) : base(source)` — clones all fields:
     - Primitives/strings: copy by value.
     - Primitive lists: `source.list == null ? null : new List<T>(source.list)`.
     - `SerializableObject` lists: iterate source and clone: `if (Core.Query.Clone(item) is ItemType item_Temp) list.Add(item_Temp);`. Do NOT cast `IEnumerable.Clone()` directly to `IList`.
     - Single nested `SerializableObject`: `field = Core.Query.Clone(source.field);`.
   - **JSON:** `ClassName(JsonObject? jsonObject) : base(jsonObject)` — empty body delegation.
4. **Properties:** `[JsonIgnore]` get-only returning field.
5. **Timestamp & Date Fields (`DateTimeOffset` Standard):**
   - Always use `DateTimeOffset` (or `DateTimeOffset?`) for timestamps and date-time properties and backing fields instead of `DateTime`.
   - `DateTime` values with `DateTimeKind.Unspecified` cause timezone offset ambiguity, local time drift, and round-trip equality assertion failures in `SerializationCheck` / JSON deserialization across environments with different UTC offsets. `DateTimeOffset` guarantees standard `ISO 8601` serialization with explicit UTC offset persistence.

---

## 6. Code Reference Snippets

### Core Architecture (`Query`, `Modify`, `Create`, `Convert`, Local Function)

```csharp
namespace DiGi.Core.Classes
{
    public class PointNode
    {
        public string? Name { get; set; }
        public double X { get; set; }
        public double Y { get; set; }
    }
}

namespace DiGi.Core
{
    public static partial class Query
    {
        // Property-like naming (no 'Get')
        public static double DistanceToOrigin(this Classes.PointNode pointNode)
        {
            return Math.Sqrt((pointNode.X * pointNode.X) + (pointNode.Y * pointNode.Y));
        }

        public static bool IsValid(this Classes.PointNode pointNode)
        {
            return !string.IsNullOrWhiteSpace(pointNode.Name);
        }
    }

    public static partial class Modify
    {
        public static void MoveNode(this Classes.PointNode pointNode, double deltaX, double deltaY)
        {
            pointNode.X += deltaX;
            pointNode.Y += deltaY;
        }
    }

    public static partial class Create
    {
        public static Classes.PointNode PointNode_ByOffset(this Classes.PointNode pointNode, double offset)
        {
            // Inline helper (local function) for single-use logic
            bool IsValidOffset(double val) => !double.IsNaN(val) && !double.IsInfinity(val);

            if (!IsValidOffset(offset))
            {
                return new();
            }

            PointNode pointNode_Result = new();
            pointNode_Result.Name = pointNode.Name + "_Offset";
            pointNode_Result.X = pointNode.X + offset;
            pointNode_Result.Y = pointNode.Y + offset;
            return pointNode_Result;
        }
    }

    public static partial class Convert
    {
        public static string? ToSystem_String(this Classes.PointNode? pointNode)
        {
            if (pointNode is null)
            {
                return null;
            }
            return $"{pointNode.Name}: ({pointNode.X}, {pointNode.Y})";
        }
    }
}
```

### `SerializableObject` Pattern

```csharp
using DiGi.Core.Classes;
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

        public Holiday(Holiday? holiday) : base(holiday)
        {
            if (holiday != null)
            {
                name = holiday.name;
                date = holiday.date;
            }
        }

        public Holiday(JsonObject? jsonObject) : base(jsonObject) { }

        [JsonIgnore]
        public string? Name => name;

        [JsonIgnore]
        public string? Date => date;
    }
}
```

---

## 7. Roslyn Analyzers & CodeFix Architecture

When implementing custom Roslyn analyzers and code fix providers (e.g. in `DiGi.Maintenance`):

1. **Project Decoupling (Rule RS1038):**
   - A Roslyn `DiagnosticAnalyzer` project must **never** reference `Microsoft.CodeAnalysis.Workspaces` or IDE packages.
   - Command-line compilers (`dotnet build`, `csc.exe`, CI pipelines) intentionally do not provide workspace assemblies, and referencing them emits compiler warning `RS1038` and risks runtime resolution crashes.
2. **Two-Project Layout:**
   - **`[Namespace].Analyzers`** (`netstandard2.0`): References only `Microsoft.CodeAnalysis.CSharp` and `Microsoft.CodeAnalysis.Analyzers`. Contains `DiagnosticAnalyzer` types that run during compilation and in IDEs.
   - **`[Namespace].Analyzers.CodeFixes`** (`netstandard2.0`): References `[Namespace].Analyzers` and `Microsoft.CodeAnalysis.CSharp.Workspaces`. Contains `CodeFixProvider` types loaded on-demand by IDEs and formatting tools (`dotnet format`).
3. **Target Framework:** `netstandard2.0` ensures broad compatibility across .NET SDKs and Visual Studio versions.

