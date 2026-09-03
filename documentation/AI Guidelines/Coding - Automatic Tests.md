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

## 3. Shared Test Data Fixtures & Test Reports

- **Shared Input Data Fixtures (`DiGi.Test/files/`):**
  - **Directory Path:** `DiGi.Test/files/` (workspace root level; do not create per-project data folders).
  - **Asset Access:** Read input files in place. Do not set `<CopyToOutputDirectory>`.
  - **Path Resolution:**
    - File path: `Core.xUnit.Query.FilePath(Assembly.GetExecutingAssembly(), "fileName.ext")`
    - Directory path: `assembly.FilesDirectory()`
    - Requires `using System.Reflection;`. Call fully-qualified: `Core.xUnit.Query.FilePath(...)`.
    - `FilePath` asserts directory existence and fails cleanly if missing.
- **Default Path for Test Reports & Diagnostic Outputs (`DiGi.Test/user files/reports/`):**
  - **Rule:** ALL reports, text dumps, benchmark logs, and diagnostic output files produced during test execution MUST be saved to `user files/reports/` (never in `files/`).
  - **Path Resolution Helpers:**
    - Reports directory: `assembly.ReportsDirectory()` or `Core.xUnit.Query.ReportsDirectory(Assembly.GetExecutingAssembly())` (resolves and creates `DiGi.Test/user files/reports/`).
    - User files directory: `assembly.UserFilesDirectory()` (resolves and creates `DiGi.Test/user files/`).
  - **Portability:** Use relative paths or extension methods. Do NOT hardcode machine-specific absolute paths.

```csharp
using System.Reflection;

// Resolving input fixture file path
string? pathInput = Core.xUnit.Query.FilePath(Assembly.GetExecutingAssembly(), "sample.gmf");
Assert.False(string.IsNullOrWhiteSpace(pathInput));
Assert.True(System.IO.File.Exists(pathInput));

// Resolving test report output path
string? pathReportsDir = Core.xUnit.Query.ReportsDirectory(Assembly.GetExecutingAssembly());
Assert.False(string.IsNullOrWhiteSpace(pathReportsDir));

string reportFilePath = System.IO.Path.Combine(pathReportsDir!, "Diagnostic_Report.txt");
System.IO.File.WriteAllLines(reportFilePath, reportLines);
```

---

## 4. Testing Patterns

- **Assertions:** Use standard xUnit assertions (`Assert.Equal`, `Assert.True`/`False`, `Assert.NotNull`/`Null`, `Assert.Single`).
- **Serialization Round-Trip:**
  - Call `Core.xUnit.Query.SerializationCheck(instance)`.
  - Validate string conversion: `Convert.ToSystem_String(object)` and `Convert.ToDiGi<T>(json)?.FirstOrDefault()`.
  - Every `SerializableObject` class must have a `[Fact]` testing constructor state, string conversion, and `SerializationCheck`.
  - **`SerializationCheck` only sees the members your instance populates.** It compares the instance's JSON against the JSON of `Clone()` — which for `SerializableObject` runs the **copy constructor** — so a member the copy constructor forgot is caught only if the fact set that member to something. A member left at its default is invisible to it, and the JSON leg keeps passing regardless, because serialization is reflection-driven and never notices. **When you add a member to a serializable type, populate it in the existing fact in the same change.** `DiGi.GIS.YOLO.UI`'s `YearBuiltPredictionPipelineOptions` gained `Radiuses`, and the same commit omitted it from the copy constructor *and* from the committed `.json.template`; the green fact could see neither, because it set `Years` and never `Radiuses`.
  - For models holding timestamps or dates, test `DateTimeOffset` properties to ensure timezone and UTC offset stability across round-trip conversions (avoiding `DateTimeKind.Unspecified` equality mismatches).
- **Tolerance Boundaries:** Test floating-point operations with test cases exactly *inside* and *outside* the boundary (`Constants.Tolerance.Distance` or `1e-3`).
- **Performance Benchmarks:**
  0. **Measure the benchmark `[Fact]` in isolation** — `dotnet test <project> -c Release --filter "FullyQualifiedName~<TestName>"`. Never read a figure off a full-suite run: xUnit executes collections in parallel, so the rest of the suite competes for cores with the thing being timed. Same code, same machine, `Mesh3D_Difference_Performance`: **983 ms in-suite vs 1306-1402 ms isolated** before a fix, then **1134 ms in-suite vs 623-790 ms isolated** after it. The distortion is not a constant offset, so an in-suite number and an isolated number are **not comparable at all** — comparing the two here would have reversed the apparent sign of a 1.9x improvement.
  1. Execute a single warm-up run to trigger JIT compilation.
  2. Measure execution time using `System.Diagnostics.Stopwatch.StartNew()`.
  3. Repeat the measurement three times and report the **range**, not a single figure.
  4. Assert execution time remains below the designated threshold (`Assert.True(stopwatch.ElapsedMilliseconds < limit)`). The asserted threshold must clear the **in-suite** time, because that is how CI runs it; report the isolated range, assert against the slower path.
  5. **A/B against a real baseline, never a stale report.** To compare two implementations, keep a copy of the pre-change file, swap it back in, and re-run isolated under identical conditions. A number from an earlier report was almost certainly produced under different conditions.
- **Comparing Two Implementations (Parity Tests):** when a rewrite, a port or a second engine has to
  agree with an existing one, the acceptance is a comparison rather than a threshold, and the shape of
  the bound decides whether the test is worth anything.
  - **Measure the distribution before stating the tolerance.** A bound guessed up front is either so
    tight it fails on legitimate noise or so loose it proves nothing. Run the comparison, look at the
    median, the percentiles and the outliers, then write the assertion.
  - **Bound a percentile, plus a structural invariant that holds for every item.** A maximum has to be
    widened until it stops detecting regressions. Proving an ONNX detector reproduced a CUDA/torch one
    over 2 000 images: median coordinate deviation **0.004 px**, 99th percentile **0.034 px**, but 2 of
    1 639 matched detections moved over a pixel and the worst moved **3.31 px**. A maximum would have
    had to be ~4 px — against a 0.004 px median, a bound that can no longer notice a real regression
    while still looking green. The percentile carries bulk agreement; a per-item invariant (there, the
    overlap of each matched pair staying above 0.95) carries the guarantee that no individual item
    drifted into being a different thing.
  - **Diagnose the outlier before excusing it.** "Floating point" is a hypothesis, not a finding. That
    3.31 px pair had **one** item on each side, so it was not a tie broken differently, and its
    confidence agreed to **1e-5** while the geometry moved — an asymmetry that pointed at one specific
    stage (a softmax expectation in stride units) rather than at noise everywhere. An outlier you
    cannot account for is a defect until shown otherwise.
  - **Put a guard band around any reporting threshold.** An item whose score sits on the cutoff
    legitimately appears on one side and not the other; counting that as disagreement makes the bar
    unmeetable. Exclude a band around the threshold from count comparisons and say so in the report.
  - **Write the report, and keep the evidence on failure.** The fact should emit the figures it
    measured to `assembly.ReportsDirectory()` and preserve both outputs when a bound is missed —
    otherwise a red build tells you a number without letting you look at the case that produced it.
  - **Guard machine-specific inputs.** A parity fact needing large models or an external interpreter
    reads their paths from a git-ignored conf and **returns without asserting** when it is absent, so
    the suite still runs everywhere. Sample size belongs in that conf too: a percentile over a handful
    of items is just the maximum again, so assert it only above a stated minimum count.
- **Reproduce Before Fixing:** a defect fix opens with a `[Fact]` that fails **on the unmodified code with the reported symptom** — matching the reported stack trace when there is one — and that `[Fact]` is committed in the same change. If a synthetic fixture will not reproduce the defect, build one from real data already in `DiGi.Test/files/`. `Mesh3D_Difference_DenseCluster` and `Mesh3D_Difference_FaultIsolation` reproduced [DiGi.Geometry#2](https://github.com/ZiolkowskiJakub/DiGi.Geometry/issues/2)'s `ConstraintEnforcementException` with its exact stack before a line of the fix was written.
- **Proving a Kept Fallback Is Dead:** when a change keeps the previous implementation as a safety net, establish whether it is reachable instead of guessing — replace the fallback call with `throw`, run the whole suite. If nothing fails, the fallback is unreached and should be deleted rather than carried. That is how `DiGi.Geometry`'s conforming-Delaunay triangulation path was retired (326 to 126 lines) with evidence.
- **A Guard Must Be Shown To Fail:** *Reproduce Before Fixing* covers a `[Fact]` written against a known defect. A guard written **proactively** — asserting a property nobody has yet violated — gets no such proof for free, and an assertion that cannot fail for the reason it exists is worse than no test, because a comment claiming it guards something stops anyone looking again.
  - **Construct the violation and watch the assertion fail**, then restore. If it still passes, the guard is decoration.
  - **Worked example.** A smoke `[Fact]` asserted a predicted year fell between 1900 and 2100, with a comment claiming an all-default row would land outside that range and so prove features were reaching the model. Measured: a row carrying **nothing but an identifier** scored `2012`. The assertion could never have caught the binding failure it was written for — the same failure that had the deployed path scoring an R² of −1.771 while throwing nothing.
  - **Prefer a differential assertion to a plausibility range.** Ranges pass on garbage. Score the same input twice — once complete, once stripped of the thing under test — and assert the results **differ**. That tests the mechanism rather than the shape of the output.

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
