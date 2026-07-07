---
name: coding-automatic-tests
description: Use when writing or adding xUnit automatic tests for C# classes, structures, or extension methods. Covers naming, Facts partial class structure, shared test-data fixtures, XML docs for tests, and serialization, tolerance, and performance test patterns.
---

# Automatic Tests (xUnit)

**Role:** Expert C# .NET QA and Software Automation Engineer.
**Task:** Generate automatic unit tests for C# classes, structures, and extension methods in this project.
**Goal:** Comprehensive, warning-free unit tests using xUnit that verify logic, edge-case tolerance boundaries, serialization correctness, and performance benchmarks.

## Strict Coding Guidelines (alignment with project standards)

1. **English Only:** All generated test code and comments MUST use English naming/terminology.
2. **Explicit Typing Mandatory:** Avoid `var`. Use explicit variable types everywhere.
   * *Example:* `double value = 5.0;` instead of `var value = 5.0;`
   * *Example:* `Core.Classes.Address address = new(...);` instead of `var address = new(...);`
   * **Target-Typed New:** use `new(...)` instead of explicit type instantiation when the target type is declared (e.g. `Address address = new(...);` not `new Address(...)`), to avoid IDE0090.
3. **Variable Naming Convention:** Variable/object names inside test methods MUST start with the object's type name in camelCase; append a descriptive suffix after `_` if needed.
   * *Complex Type Examples:* `PointNode pointNode_Base`, `PointNode pointNode_Temp`, `Segment3D segment3D_Inside`.
   * **Plural Naming for Collections:** don't prefix with the collection type (avoid `listPoints`, `arraySegments`); use the element type name pluralized (`point3Ds`, `segment3Ds`).
   * **Exception for Primitive/Simple Types:** standard camelCase is fine for `double`, `string`, `int`, `bool`, etc. (`double tolerance`, `string name`, `int count`, `double result`).
4. **Zero Warnings & Messages:** No compiler warnings or analyzer messages; handle nullability (`?`) correctly.

## xUnit Testing Standards & Project Structure

1. **Test Project Separation:** test projects follow `[ProjectName].xUnit` (e.g. `DiGi.Core.xUnit`, `DiGi.Geometry.xUnit`).
2. **Partial Test Class (`Facts`):** all test methods live inside `public partial class Facts`, grouping all tests per namespace.
3. **Directory Structure:** place test files inside the `/Facts` directory of the test project.
4. **Namespace Convention:** namespace of the test file matches the test project namespace (e.g. `DiGi.Core.xUnit`, `DiGi.Geometry.xUnit`).
5. **Global Usings:** `Xunit` is globally imported via project configuration — do NOT add `using Xunit;`.
6. **Attributes:** use `[Fact]` to mark test methods.
7. **Method Naming:** name test methods after the class/property/method under test (e.g. `Color()`, `PlanarIntersectionResult_Performance()`).
8. **XML Documentation for Tests:**
   * Every test method MUST have a `<summary>` block describing what is tested.
   * No empty lines within XML doc blocks (causes tooltip rendering issues in Visual Studio) — use `<para>` for paragraph breaks instead.

## Shared Test Data Files (Fixtures)

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

## Common Testing Patterns & Assertions

### 1. Basic Assertions
`Assert.Equal(expected, actual)`, `Assert.True(condition)` / `Assert.False(condition)`, `Assert.NotNull(object)` / `Assert.Null(object)`, `Assert.Single(collection)`.

### 2. Serialization and Deserialization Round-Trip
* Standard object serialization validation: `Query.SerializationCheck(object_Instance);`
* String/JSON serialization: `Convert.ToSystem_String(object)` and `Convert.ToDiGi<T>(json)?.FirstOrDefault()` for deserialization.
* `SerializationCheck` lives in `DiGi.Core.xUnit`. When the test project's own namespace differs (e.g. `DiGi.EPW.xUnit` testing classes from `DiGi.EPW`), call it fully qualified as `Core.xUnit.Query.SerializationCheck(object_Instance);` — this relies on the same "innermost-enclosing-namespace" lookup as `Core.Query.Clone(...)` (see Coding - General's Serialization Pattern section), so it resolves without an explicit `using DiGi.Core.xUnit;` as long as the test namespace nests under `DiGi`.
* For every class added under the `SerializableObject` pattern (see Coding - General skill), add one `[Fact]` per class that constructs an instance with realistic values (including `null` for optional fields, and at least one populated nested list/object), asserts the constructor's properties, then calls `SerializationCheck` — this exercises both JSON round-trip and the `Clone()`/`Core.Query.Clone()` copy-constructor paths in one go.

### 3. Tolerance Boundaries
For geometric/math operations, test behavior at the boundary of a given tolerance (e.g. `1e-3` or `Constants.Tolerance.Distance`):
* Case exactly inside the boundary.
* Case exactly outside the boundary.

### 4. Performance Benchmarks
* **Warm-up Block:** run the target logic once before measuring, to allow JIT compilation.
* **Stopwatch Measurement:** `System.Diagnostics.Stopwatch.StartNew()`.
* **Large Dataset:** use complex/large datasets (e.g. a polyline with 1000 vertices).
* **Execution Assertion:** assert elapsed time below a threshold (e.g. `Assert.True(stopwatch.ElapsedMilliseconds < 5, ...)`).

## Code Examples

### Example 1: Basic Logic Test (`/Facts/Round.cs`)
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

### Example 2: Serialization and Conversions Test (`/Facts/Color.cs`)
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

### Example 3: Performance Benchmark & Boundary Test (`/Facts/PlanarIntersectionResult.cs`)
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
