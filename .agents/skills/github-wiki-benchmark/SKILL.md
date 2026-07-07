---
name: github-wiki-benchmark
description: Use when authoring or updating the Benchmark page on a DiGi repository's GitHub Wiki. Covers page structure, test machine specs, and benchmark guidelines.
---

# GitHub Wiki — Benchmark Pages

Standard for authoring the **`Benchmark`** page on a DiGi repo's GitHub Wiki, so every repo presents performance data the same way. Read this before creating or updating benchmark docs.

Reference implementations that follow this standard:
- **DiGi.Geometry** (native CPU query comparisons) — https://github.com/ZiolkowskiJakub/DiGi.Geometry/wiki/Benchmark
- **DiGi.ComputeSharp** (GPU vs CPU) — https://github.com/ZiolkowskiJakub/DiGi.ComputeSharp/wiki/Benchmark

## Purpose & scope
A `Benchmark` page documents **reproducible** performance (and, where relevant, correctness) comparisons. Every number must come from a committed `[Fact]` test in that repo's `*.xUnit` project so a reader can re-run it rather than trust a one-off snapshot. **The page lives on the wiki of the repo whose methods it benchmarks** (e.g. a `DiGi.Geometry.Planar.Query` comparison → the DiGi.Geometry wiki, backed by a test in `DiGi.Geometry.xUnit`). Method names are always fully namespace-qualified; if an entry compares a method from another assembly, qualify that too and keep the page on the repo owning the primary subject under test.

## Location, file & sync
See `github-wiki-general` for full mechanics. In short:
- **File:** `Benchmark.md` at the wiki clone root (`DigiProject/wiki/<repo>.wiki/Benchmark.md`), rendered at `.../<repo>/wiki/Benchmark`.
- **Branch `master`:** commit and `git push origin HEAD` to publish — a page doesn't exist until pushed.
- **Hand-authored:** the sync only copies generated `documentation/API/*` pages, so it never deletes `Benchmark.md` — edit and push it directly.
- **Link it from `Home.md`** so it is discoverable.

## Required page structure (in this order)
1. **Title + intro:** `# Benchmark` then one short paragraph stating what is compared and that all benchmarks live as `[Fact]` tests in `<repo>.xUnit` (give the `Facts/` path) so they are re-runnable.
2. **Test machine spec:** a two-column table + the caveat line. Include only rows that matter for the workload (drop **GPU** for CPU-only benchmarks). Capture the spec on the actual run machine (`Get-CimInstance Win32_Processor / Win32_OperatingSystem / Win32_ComputerSystem`, `dotnet --version`) — never copy stale specs from another page.

   ```markdown
   ## Test machine spec

   | Component | Specification |
   |---|---|
   | CPU | AMD Ryzen 9 9950X, 16 cores / 32 threads (`Environment.ProcessorCount = 32`) |
   | GPU | NVIDIA GeForce RTX 5090 |
   | RAM | 61.4 GB |
   | OS | Windows 11 Pro (10.0.26200) |
   | .NET SDK | 10.0.301 |
   | Build config | Release (unless noted) |

   Numbers are machine-specific — re-run the benchmarks on your own hardware before drawing conclusions for a different environment.
   ```
3. **One `##` section per benchmark**, header `## <human-readable title> — \`<TestMethodName>\``, containing in order:
   - **`File:`** — the `Facts/<File>.cs` holding the test.
   - **Methods compared** — every method, **fully namespace-qualified with its parameter list**, e.g. `DiGi.Geometry.Planar.Query.Average(IEnumerable<Point2D>)` (mandatory — a reader must find the exact method without guessing).
   - **Description** — the workload run and what is measured.
   - **Editable knobs** — the single `const`/`static readonly` sweep field(s) at the top of the test class, with example high/low values.
   - **Result table(s)** — right-align numeric columns (`|---:|`). **Release** is the primary table; a **Debug** table may follow, labelled *for reference*, when it tells an additional story. Include a ratio/speed-up column.
   - **Analysis** — short bullets interpreting the numbers (crossovers, where a method wins/loses, what dominates cost, honest variance caveats).
4. **`## Adding a new benchmark`** — the checklist below.

## Conventions (keep numbers trustworthy)
1. **Reproducible** — every figure comes from a committed `[Fact]`; name the test and its file. No hand-typed numbers.
2. **Fully-qualified method names** — always `Namespace.Class.Method(params)`, never a bare name (especially on the DiGi.Core hub page where methods come from sibling assemblies).
3. **Report build config** per table. Release is representative; if you show Debug, label it *for reference* and explain the difference (JIT optimization changes the story).
4. **Warm up before timing** — call each method once (small input) before the measured loop to exclude JIT / shader-compilation cost.
5. **Assert cross-implementation agreement** — when comparing implementations, assert they produce the same result so timings measure equivalent work.
6. **Keep work comparable across scales** — for a point-count sweep, scale the repeat count inversely (e.g. `repeats = Max(1, TARGET_OPS / count)`) and report **per-call** time (µs/ms per call), not raw loop time.
7. **Deterministic inputs** — seed any RNG with a fixed constant and note the seed on the page.
8. **Be honest about noise** — at tiny inputs or few repeats, overhead and GC can dominate and even invert the expected ratio; say so rather than cherry-picking a run.
9. **Refresh, don't append duplicates** — re-running updates the existing table in place; keep one table per benchmark, matching the current code.

## Adding a new benchmark (checklist)
1. Add a `[Fact]` under `Facts/` in the repo's `*.xUnit` project, following the repo's test conventions (`partial class Facts`, XML `<summary>`, explicit types, warm-up-then-`Stopwatch`).
2. Expose the sweep size(s) as a single `const`/`static readonly` field at the top of the class so it can scale up for a stress run and down for fast everyday runs.
3. Warm up (small input) before timing to exclude JIT / shader-compilation cost.
4. Assert cross-implementation agreement (result values / counts) so timing covers equivalent work.
5. Run in **Release** to capture representative numbers; capture the current machine spec.
6. Add/refresh the `##` section: title + test name, file, fully-qualified methods, description, knobs, result table(s), analysis.
7. Commit and `git push origin HEAD` from the `<repo>.wiki` clone. Ensure `Home.md` links the page.
