---
name: coding-automatic-tests
description: Use when writing or adding xUnit tests for C# classes, structs, or extension methods - Facts partial class structure, naming, shared test-data fixtures, and serialization, tolerance-boundary, and performance test patterns.
---

# AI Guidelines: Automatic Tests

**Role:** Expert C# .NET QA / software automation engineer.
**Goal:** Generate comprehensive, warning-free xUnit tests for the project's classes, structs, and extension methods — covering logic, edge-case tolerance boundaries, serialization correctness, and performance benchmarks.

## Coding rules (match production code)
1. **English only** for all test code and comments.
2. **Explicit typing — no `var`.** Use target-typed `new(...)` when the type is declared (avoids IDE0090): `double value = 5.0;` and `Address address = new(...);`, not `var value = 5.0;` or `new Address(...)`.
3. **Variable naming:** start with the type name in camelCase, adding a `_`-suffixed qualifier when needed (`PointNode pointNode_Base`, `PointNode pointNode_Temp`, `Segment3D segment3D_Inside`). For collections, don't prefix with the collection type — use the element type pluralized (`point3Ds`/`segment3Ds`, not `listPoints`/`points`/`listSegments`). Primitives may use plain camelCase (`double tolerance`, `int count`, `double result`).
4. **Zero warnings/analyzer messages** — honour nullability (`?` and appropriate null handling).

## xUnit structure
1. **One test project per project:** `[ProjectName].xUnit` (e.g. `DiGi.Core.xUnit`, `DiGi.Geometry.xUnit`).
2. **`public partial class Facts`** holds all test methods (one shared class per namespace).
3. **Files under `/Facts`.**
4. **Namespace matches the test project** (e.g. `namespace DiGi.Core.xUnit`).
5. **`Xunit` is global-usinged** by project config — do NOT add `using Xunit;`.
6. **`[Fact]`** marks test methods.
7. **Name the method** after the class/property/method under test (`Color()`, `PlanarIntersectionResult_Performance()`).
8. **XML `<summary>` on every test** describing what is tested — no empty lines inside the block (they break VS tooltips); use `<para>` for paragraph breaks.

## Shared test data files (fixtures)
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

## Testing patterns
1. **Assertions:** `Assert.Equal(expected, actual)`, `Assert.True`/`False(condition)`, `Assert.NotNull`/`Null(object)`, `Assert.Single(collection)` (exactly one element).
2. **Serialization round-trip:** `Query.SerializationCheck(instance)` (lives in `DiGi.Core.xUnit`; from another test project call it fully qualified as `Core.xUnit.Query.SerializationCheck(instance)` — same innermost-enclosing-namespace lookup as `Core.Query.Clone(...)`, so no `using DiGi.Core.xUnit;` is needed under the `DiGi` root). For string/JSON, use `Convert.ToSystem_String(object)` and `Convert.ToDiGi<T>(json)?.FirstOrDefault()`. For every class under the `SerializableObject` pattern, add one `[Fact]` that constructs an instance with realistic values (`null` for optional fields, at least one populated nested list/object), asserts the constructor's properties, then calls `SerializationCheck` — this exercises both the JSON round-trip and the `Clone()`/`Core.Query.Clone()` copy-constructor paths in one go.
3. **Tolerance boundaries:** for geometry/math operations (e.g. `1e-3` or `Constants.Tolerance.Distance`), test cases exactly inside the boundary and exactly outside it.
4. **Performance benchmarks:** warm up once to trigger JIT, then measure with `System.Diagnostics.Stopwatch.StartNew()` over a large/complex dataset (e.g. a 1000-vertex polyline), then assert the elapsed time is below a stated millisecond threshold.

## Code examples

### Example 1: Basic logic test (`/Facts/Round.cs`)
```csharp
namespace DiGi.Core.xUnit
{
    public partial class Facts
    {
        /// <summary>
        /// Tests that the rounding functionality correctly processes a zero value using the defined distance tolerance.
        /// </summary>
        [Fact]
        public void Round()
        {
            double value = Core.Query.Round(0, Constants.Tolerance.Distance);

            Assert.Equal(0.0, value);
        }
    }
}
```

### Example 2: Serialization and conversions test (`/Facts/Color.cs`)
```csharp
using System.Linq;

namespace DiGi.Core.xUnit
{
    public partial class Facts
    {
        /// <summary>
        /// Tests the functionality of the Color class, verifying the conversion between System.Drawing.Color and string representations, as well as ensuring that ARGB values are preserved during these conversions and validating serialization.
        /// </summary>
        [Fact]
        public void Color()
        {
            System.Drawing.Color drawingColor_1 = System.Drawing.Color.Aqua;

            Core.Classes.Color color_1 = new(drawingColor_1);

            string? string_1 = color_1.ToSystem_String();

            Assert.NotNull(string_1);

            Core.Classes.Color? color_2 = Convert.ToDiGi<Core.Classes.Color>(string_1)?.FirstOrDefault();

            Assert.NotNull(color_2);

            string? string_2 = color_2.ToSystem_String();

            Assert.NotNull(string_2);

            Assert.Equal(string_1, string_2);

            Core.Classes.Color? color_3 = Convert.ToDiGi<Core.Classes.Color>(string_2)?.FirstOrDefault();

            Assert.Equal(color_3.ToSystem_String(), string_2);

            System.Drawing.Color drawingColor_2 = color_3.ToDrawing();

            Assert.Equal(drawingColor_1.A, drawingColor_2.A);
            Assert.Equal(drawingColor_1.R, drawingColor_2.R);
            Assert.Equal(drawingColor_1.G, drawingColor_2.G);
            Assert.Equal(drawingColor_1.B, drawingColor_2.B);

            Query.SerializationCheck(color_1);
        }
    }
}
```

### Example 3: Performance benchmark & boundary test (`/Facts/PlanarIntersectionResult.cs`)
```csharp
using DiGi.Geometry.Spatial;
using DiGi.Geometry.Spatial.Classes;
using DiGi.Geometry.Spatial.Interfaces;
using DiGi.Geometry.Planar.Classes;

namespace DiGi.Geometry.xUnit
{
    public partial class Facts
    {
        /// <summary>
        /// Tests planar intersections at tolerance boundaries.
        /// </summary>
        [Fact]
        public void PlanarIntersectionResult_ToleranceBoundaries()
        {
            Plane plane = Spatial.Constants.Plane.WorldZ;
            double tolerance = 1e-3;

            // Endpoint exactly inside boundary (Z = tolerance - 1e-9)
            Segment3D segment3D_Inside = new(new Point3D(0, 0, 1e-3 - 1e-9), new Point3D(0, 0, 10));
            PlanarIntersectionResult? planarIntersectionResult_Inside = Create.PlanarIntersectionResult(plane, segment3D_Inside, tolerance);
            Assert.NotNull(planarIntersectionResult_Inside);
            Assert.True(planarIntersectionResult_Inside.Intersect);

            // Endpoint exactly outside boundary (Z = tolerance + 1e-9)
            Segment3D segment3D_Outside = new(new Point3D(0, 0, 1e-3 + 1e-9), new Point3D(0, 0, 10));
            PlanarIntersectionResult? planarIntersectionResult_Outside = Create.PlanarIntersectionResult(plane, segment3D_Outside, tolerance);
            Assert.NotNull(planarIntersectionResult_Outside);
            Assert.False(planarIntersectionResult_Outside.Intersect);
        }

        /// <summary>
        /// Tests the performance of planar intersection calculations.
        /// </summary>
        [Fact]
        public void PlanarIntersectionResult_Performance()
        {
            Plane plane = Spatial.Constants.Plane.WorldZ;

            // Warm up / JIT compile before measuring performance
            {
                Polyline3D polyline_Warmup = new([new Point3D(0, 0, 10)]);
                _ = Create.PlanarIntersectionResult(plane, polyline_Warmup);
                BoundingBox3D box_Warmup = new(new Point3D(-1, -1, 2), new Point3D(1, 1, 4));
                Polyhedron? poly_Warmup = Create.Polyhedron(box_Warmup);
                if (poly_Warmup != null)
                {
                    _ = Create.PlanarIntersectionResult(plane, poly_Warmup);
                }
            }

            // Complex Polyline with 1000 vertices completely disjoint from plane
            List<Point3D> point3Ds = [];
            for (int i = 0; i < 1000; i++)
            {
                point3Ds.Add(new Point3D(i, i, 10));
            }
            Polyline3D polyline3D_Complex = new(point3Ds);

            System.Diagnostics.Stopwatch stopwatch = System.Diagnostics.Stopwatch.StartNew();
            PlanarIntersectionResult? planarIntersectionResult = Create.PlanarIntersectionResult(plane, polyline3D_Complex);
            stopwatch.Stop();

            Assert.NotNull(planarIntersectionResult);
            Assert.False(planarIntersectionResult.Intersect);
            Assert.True(stopwatch.ElapsedMilliseconds < 5, $"Early exit performance check failed for ISegmentable3D! Took {stopwatch.ElapsedMilliseconds} ms.");
        }
    }
}
```

