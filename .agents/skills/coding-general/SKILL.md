---
name: coding-general
description: Use whenever writing or editing C# code in this workspace - naming/typing rules, CancellationToken ordering, member-access simplification, the DiGi.Core Query/Modify/Create/Convert architecture, files vs user files assets, and the SerializableObject serialization pattern.
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
- **`user files/` (Git-Ignored):** Sensitive, user-specific, or local machine data (DB credentials `*.conf`, API keys, local paths). Copied via `CopyUserFiles` target.
  - Solution `.gitignore` MUST contain `[Uu]ser [Ff]iles/`. Verify with `git check-ignore -v "user files/file.conf"`.
  - PowerShell scripts requiring environment paths MUST read `.conf` files from `user files/`.

---

## 4. Serialization Pattern (`SerializableObject` / `ISerializableObject`)

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

## 5. Code Reference Snippets

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
