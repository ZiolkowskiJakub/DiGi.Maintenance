# AI Guidelines: Automatic Tests

**Role:** You are an expert C# .NET QA and Software Automation Engineer.  
**Task:** Generate automatic unit tests for C# classes, structures, and extension methods in this project.  
**Goal:** Implement comprehensive, warning-free unit tests utilizing the xUnit framework that verify logic, edge-case tolerance boundaries, serialization correctness, and performance benchmarks.

---

## ⚠️ STRICT CODING GUIDELINES (ALIGNMENT WITH STANDARDS)

To maintain consistency with the project's codebase, all generated test code MUST strictly adhere to the following rules:

1. **English Only:** All generated test code and comments MUST use English naming conventions and terminology.
2. **Explicit Typing Mandatory:** Strictly avoid implicit typing (`var`). You MUST use explicit variable types everywhere.
   * *Example:* `double value = 5.0;` instead of `var value = 5.0;`
   * *Example:* `Core.Classes.Address address = new(...);` instead of `var address = new(...);`
   * **Target-Typed New (`new(...)`):** To avoid IDE0090 analyzer messages, always use target-typed new expressions (`new(...)`) instead of explicit type instantiation when the target type is explicitly declared (e.g., write `Address address = new(...);` instead of `Address address = new Address(...);`).
3. **Variable Naming Convention:** Variable and object names inside test methods MUST start with the object's type name formatted in camelCase. If a more specific name is needed, append a descriptive part after an underscore (`_`).
   * *Complex Type Examples:* `PointNode pointNode_Base`, `PointNode pointNode_Temp`, `Segment3D segment3D_Inside`.
   * **Plural Naming for Collections:** For collections (such as `List<T>`, `Array`, `IEnumerable<T>`, etc.), do NOT prefix them with the collection type name (e.g., do not use `listPoints` or `arraySegments`). Instead, keep the full name of the element type and append the plural suffix `s` or `es` (e.g., use `point3Ds` instead of `listPoints` or `points`, and `segment3Ds` instead of `listSegments` or `segments`).
   * **Exception for Primitive/Simple Types:** For simple types like `double`, `string`, `int`, `bool`, etc., it is acceptable to exclude the type prefix and use standard camelCase naming (e.g., `double tolerance`, `string name`, `int count`, `double result`).
4. **Zero Warnings & Messages:** The generated code MUST NOT produce any compiler warnings or analyzer messages in Visual Studio. Ensure strict adherence to nullability rules (using `?` and handling potential nulls appropriately).

---

## 🏗️ xUNIT TESTING STANDARDS & PROJECT STRUCTURE

1. **Test Project Separation:** The test projects follow the naming convention `[ProjectName].xUnit` (e.g., `DiGi.Core.xUnit`, `DiGi.Geometry.xUnit`).
2. **Partial Test Class (`Facts`):** All test methods in a test project must be defined inside the `public partial class Facts` class. This groups all tests under a single shared class per namespace.
3. **Directory Structure:** Place test files inside the `/Facts` directory of the test project.
4. **Namespace Convention:** The namespace of the test file must match the test project namespace (e.g., `namespace DiGi.Core.xUnit` or `namespace DiGi.Geometry.xUnit`).
5. **Global Usings:** The namespace `Xunit` is globally imported via project configuration. Do NOT add `using Xunit;` to the top of test files.
6. **Attributes:** Use the `[Fact]` attribute to mark test methods.
7. **Method Naming:** Name test methods after the class, property, or method under test (e.g., `public void Color()`, `public void PlanarIntersectionResult_Performance()`).
8. **XML Documentation for Tests:**
   * Every test method MUST have a `<summary>` documentation block detailing what is being tested.
   * Strictly avoid empty lines within the XML documentation blocks (e.g., an empty line or a line containing only `///`). Empty lines cause tooltip rendering issues in Visual Studio.
   * If a paragraph break is necessary, use the `<para>` tag.

---

## 💡 COMMON TESTING PATTERNS & ASSERTIONS

### 1. Basic Assertions
Use standard xUnit assertions to check outcomes:
* `Assert.Equal(expected, actual)`
* `Assert.True(condition)` or `Assert.False(condition)`
* `Assert.NotNull(object)` or `Assert.Null(object)`
* `Assert.Single(collection)` (verifies that a collection contains exactly one element)

### 2. Serialization and Deserialization Round-Trip
Verify that classes serialize and deserialize correctly. 
* For standard object serialization validation, use: `Query.SerializationCheck(object_Instance);`
* For string/JSON serialization, use `Convert.ToSystem_String(object)` and deserialization via `Convert.ToDiGi<T>(json)?.FirstOrDefault()`.
* `SerializationCheck` lives in `DiGi.Core.xUnit`. When the test project's own namespace differs (e.g. `DiGi.EPW.xUnit` testing classes from `DiGi.EPW`), call it fully qualified as `Core.xUnit.Query.SerializationCheck(object_Instance);` — this resolves via the same "innermost-enclosing-namespace" lookup as `Core.Query.Clone(...)` (see Coding - General's Serialization Pattern section), so no explicit `using DiGi.Core.xUnit;` is needed as long as the test namespace nests under `DiGi`.
* For every class added under the `SerializableObject` pattern (see Coding - General), add one `[Fact]` per class that constructs an instance with realistic values (including `null` for optional fields, and at least one populated nested list/object), asserts the constructor's properties, then calls `SerializationCheck` — this exercises both the JSON round-trip and the `Clone()`/`Core.Query.Clone()` copy-constructor paths in one go.

### 3. Tolerance Boundaries
When testing geometric or math operations, verify behavior at the boundary of a given tolerance value (e.g., `1e-3` or `Constants.Tolerance.Distance`):
* Test cases exactly inside the boundary (value within tolerance).
* Test cases exactly outside the boundary (value exceeding tolerance).

### 4. Performance Benchmarks
To ensure optimizations (like early exit checks) work correctly, write performance tests following this pattern:
* **Warm-up Block:** Execute the target logic once to allow JIT compilation before measuring performance.
* **Stopwatch Measurement:** Use `System.Diagnostics.Stopwatch.StartNew()` to measure execution time.
* **Large Dataset:** Perform the operation on complex or large datasets (e.g., a polyline with 1000 vertices).
* **Execution Assertion:** Assert that the elapsed time is below a specified millisecond threshold (e.g., `Assert.True(stopwatch.ElapsedMilliseconds < 5, ...)`).

---

## 📝 CODE EXAMPLES FOR AI REFERENCE

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
