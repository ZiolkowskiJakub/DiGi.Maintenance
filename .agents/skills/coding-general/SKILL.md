---
name: coding-general
description: Use whenever writing or editing C# code in this workspace - naming/typing rules, CancellationToken ordering, member-access simplification, the DiGi.Core Query/Modify/Create/Convert architecture, cheap constructors with validation and normalisation moved into a Create factory, the one-member-per-file layout for Query/Modify/Create and nested types, files vs user files assets, the SerializableObject serialization pattern, and the host PackageReference rules for NuGet dependencies that HintPath references drop (a runtime FileNotFoundException that shows up as a partial result, not an error).
---

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
6. **Parameter Line Breaks (`<= 5` Rule):**
   - **<= 5 parameters:** Must remain on a **single line**.
   - **>= 6 parameters:** Split parameters onto multiple lines.
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

---

## 3. Solution Assets — `files/` vs `user files/`

- **`files/` (Committed):** Non-sensitive, shared deployment assets (`web.config`, `app_offline.htm.bak`). Copied to build output via `CopyFiles` MSBuild target.
- **`user files/` (Git-Ignored):** Sensitive, user-specific, local machine data (DB credentials `*.conf`, API keys, local paths), and test report outputs (`user files/reports/`). Copied via `CopyUserFiles` target.
  - Solution `.gitignore` MUST contain `[Uu]ser [Ff]iles/`. Verify with `git check-ignore -v "user files/file.conf"`.
  - PowerShell scripts requiring environment paths MUST read `.conf` files from `user files/`.
  - Automated test reports, diagnostic dumps, and text logs produced during test execution MUST be saved to `user files/reports/` (resolved via `assembly.ReportsDirectory()`).

---

## 4. Host Dependencies — `HintPath` Drops Transitive NuGet Packages

DiGi projects reference each other with `<Reference><HintPath>..\..\X\bin\X.dll</HintPath>`, never
`<ProjectReference>`. A raw assembly reference is **opaque to NuGet**, and the DiGi class libraries do
not copy their own NuGet dependencies into their `bin`. A library's third-party dependencies therefore
never reach a host that consumes it by `HintPath`.

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
