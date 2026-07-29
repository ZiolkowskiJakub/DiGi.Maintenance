---
name: coding-automatic-tests
description: Use when writing or adding xUnit tests for C# classes, structs, or extension methods - Facts partial class structure, naming, shared test-data fixtures, and serialization, tolerance-boundary, and performance test patterns.
---

# AI Guidelines: Automatic Tests

**Goal:** Generate warning-free xUnit tests covering logic, edge-case tolerance boundaries, serialization correctness, and performance benchmarks.

---

## 1. Coding Rules

- Conform strictly to production C# guidelines (see [Coding - General.md](Coding%20-%20General.md)): English only, explicit typing (no `var`), camelCase naming with type prefixes (`pointNode_Base`), plural element collection names (`point3Ds`), zero compiler/analyzer warnings.

---

## 2. xUnit Project Structure

- **Naming:** One test project per project: `[ProjectName].xUnit` (e.g. `DiGi.Core.xUnit`).
- **Test Class:** `public partial class Facts` under `/Facts/` directory. One shared `Facts` class per namespace.
- **Namespace:** Matches test project (`namespace DiGi.Core.xUnit`).
- **Usings:** `Xunit` is configured as a global using — **do NOT add `using Xunit;`**.
- **Attributes:** Mark test methods with `[Fact]`.
- **Method Naming:** Name method directly after target class/property/method (`Color()`, `PlanarIntersectionResult_Performance()`).
- **Documentation:** Include XML `<summary>` on every test method. Do not leave blank lines in doc blocks; use `<para>`.

---

## 3. Shared Test Data Fixtures

- **Directory Path:** `DiGi.Test/files/` (workspace root level; do not create per-project data folders).
- **Asset Access:** Read files in place. Do not set `<CopyToOutputDirectory>`.
- **Path Resolution:**
  - File path: `Core.xUnit.Query.FilePath(Assembly.GetExecutingAssembly(), "fileName.ext")`
  - Directory path: `assembly.FilesDirectory()`
  - Requires `using System.Reflection;`. Call fully-qualified: `Core.xUnit.Query.FilePath(...)`.
  - `FilePath` asserts directory existence and fails cleanly if missing.

```csharp
using System.Reflection;

string? path = Core.xUnit.Query.FilePath(Assembly.GetExecutingAssembly(), "sample.gmf");
Assert.False(string.IsNullOrWhiteSpace(path));
Assert.True(System.IO.File.Exists(path));
```

---

## 4. Testing Patterns

- **Assertions:** Use standard xUnit assertions (`Assert.Equal`, `Assert.True`/`False`, `Assert.NotNull`/`Null`, `Assert.Single`).
- **Serialization Round-Trip:**
  - Call `Core.xUnit.Query.SerializationCheck(instance)`.
  - Validate string conversion: `Convert.ToSystem_String(object)` and `Convert.ToDiGi<T>(json)?.FirstOrDefault()`.
  - Every `SerializableObject` class must have a `[Fact]` testing constructor state, string conversion, and `SerializationCheck`.
- **Tolerance Boundaries:** Test floating-point operations with test cases exactly *inside* and *outside* the boundary (`Constants.Tolerance.Distance` or `1e-3`).
- **Performance Benchmarks:**
  1. Execute a single warm-up run to trigger JIT compilation.
  2. Measure execution time using `System.Diagnostics.Stopwatch.StartNew()`.
  3. Assert execution time remains below the designated threshold (`Assert.True(stopwatch.ElapsedMilliseconds < limit)`).

---

## 5. Reference Examples

### Basic Test & Serialization (`/Facts/Color.cs`)

```csharp
using System.Linq;

namespace DiGi.Core.xUnit
{
    public partial class Facts
    {
        /// <summary>
        /// Tests Color conversion between System.Drawing.Color and string formats, validating ARGB preservation and serialization.
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

            System.Drawing.Color drawingColor_2 = color_2.ToDrawing();
            Assert.Equal(drawingColor_1.A, drawingColor_2.A);
            Assert.Equal(drawingColor_1.R, drawingColor_2.R);
            Assert.Equal(drawingColor_1.G, drawingColor_2.G);
            Assert.Equal(drawingColor_1.B, drawingColor_2.B);

            Core.xUnit.Query.SerializationCheck(color_1);
        }
    }
}
```

### Boundary & Benchmark Test (`/Facts/PlanarIntersectionResult.cs`)

```csharp
using DiGi.Geometry.Spatial;
using DiGi.Geometry.Spatial.Classes;

namespace DiGi.Geometry.xUnit
{
    public partial class Facts
    {
        /// <summary>
        /// Tests planar intersections at tolerance boundaries and measures execution performance.
        /// </summary>
        [Fact]
        public void PlanarIntersectionResult_ToleranceBoundaries()
        {
            Plane plane = Spatial.Constants.Plane.WorldZ;
            double tolerance = 1e-3;

            // Inside boundary (Z = tolerance - 1e-9)
            Segment3D segment3D_Inside = new(new Point3D(0, 0, 1e-3 - 1e-9), new Point3D(0, 0, 10));
            PlanarIntersectionResult? result_Inside = Create.PlanarIntersectionResult(plane, segment3D_Inside, tolerance);
            Assert.NotNull(result_Inside);
            Assert.True(result_Inside.Intersect);

            // Outside boundary (Z = tolerance + 1e-9)
            Segment3D segment3D_Outside = new(new Point3D(0, 0, 1e-3 + 1e-9), new Point3D(0, 0, 10));
            PlanarIntersectionResult? result_Outside = Create.PlanarIntersectionResult(plane, segment3D_Outside, tolerance);
            Assert.NotNull(result_Outside);
            Assert.False(result_Outside.Intersect);
        }

        [Fact]
        public void PlanarIntersectionResult_Performance()
        {
            Plane plane = Spatial.Constants.Plane.WorldZ;

            // Warm up / JIT compile
            Polyline3D polyline_Warmup = new([new Point3D(0, 0, 10)]);
            _ = Create.PlanarIntersectionResult(plane, polyline_Warmup);

            List<Point3D> point3Ds = [];
            for (int i = 0; i < 1000; i++)
            {
                point3Ds.Add(new Point3D(i, i, 10));
            }
            Polyline3D polyline3D_Complex = new(point3Ds);

            System.Diagnostics.Stopwatch stopwatch = System.Diagnostics.Stopwatch.StartNew();
            PlanarIntersectionResult? result = Create.PlanarIntersectionResult(plane, polyline3D_Complex);
            stopwatch.Stop();

            Assert.NotNull(result);
            Assert.False(result.Intersect);
            Assert.True(stopwatch.ElapsedMilliseconds < 5, $"Intersection check failed threshold! Elapsed: {stopwatch.ElapsedMilliseconds} ms.");
        }
    }
}
```
