---
name: github-wiki-benchmark
description: Use when creating or updating a repo's Benchmark GitHub wiki page - required page structure, reproducible-numbers conventions, and the checklist for adding a new benchmark entry.
---

# GitHub Wiki — Benchmark Pages

Standard specification for authoring `Benchmark.md` performance pages across DiGi GitHub Wikis.

---

## 1. Purpose & Scope

- **Requirement:** Every number must originate from a committed `[Fact]` test in the repository's `*.xUnit` project (`Facts/` directory). Hand-typed or unverified figures are prohibited.
- **Location:** `Benchmark.md` at wiki clone root (`DigiProject/wiki/<repo>.wiki/Benchmark.md`). Link from `Home.md`.
- **Method Qualification:** Method names in benchmark entries MUST be **fully namespace-qualified with parameter signatures**.

---

## 2. Mandatory Page Structure (Strict Sequence)

1. **Title & Introduction:** `# Benchmark` followed by a concise summary of tested workloads and pointer to `[Fact]` source code in `<repo>.xUnit`.
2. **Test Machine Specification:** Two-column table captured from actual benchmark machine (`Get-CimInstance`, `dotnet --version`):
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

   Numbers are machine-specific — re-run benchmarks on your own hardware before drawing comparative conclusions.
   ```
   *(Omit GPU row for CPU-only benchmarks).*
3. **Benchmark Sections (`## <Title> — \`<TestMethodName>\``):** Include in exact order:
   - `**File:**` `Facts/<FileName>.cs`
   - **Methods Compared:** Fully-qualified method signatures (`DiGi.Geometry.Planar.Query.Average(IEnumerable<Point2D>)`).
   - **Description:** Workload overview.
   - **Editable Knobs:** `const`/`static readonly` sweep fields.
   - **Result Tables:** Right-align numeric columns (`|---:|`). Release build is mandatory primary table; Debug table labeled *for reference*. Include speed-up/ratio column.
   - **Analysis:** Short bullet points interpreting crossovers, bottlenecks, and variances.
4. **Section `## Adding a new benchmark`:** Include the execution checklist.

---

## 3. Core Benchmark Conventions

1. **Reproducibility:** All data backed by committed `[Fact]` methods.
2. **Full Method Qualification:** `Namespace.Class.Method(ParamTypes)`.
3. **Build Config Labeling:** Explicitly declare Release vs Debug.
4. **Warm-Up Execution:** Invoke each method once on small input before starting `Stopwatch` to exclude JIT and shader compilation overhead.
5. **Correctness Assertion:** Assert cross-implementation result agreement before measuring time.
6. **Per-Call Metrics:** Scale iteration counts inversely (`repeats = Math.Max(1, TARGET_OPS / count)`) and report time **per call** (µs or ms), not total loop duration.
7. **Deterministic Randomness:** Seed RNGs with explicit constants and document seed.
8. **Noise Transparency:** Note measurement noise or GC overhead at small scales.
9. **In-Place Refresh:** Overwrite existing tables when re-running benchmarks — do not append historical duplicate runs.
10. **Isolated Execution:** Every figure on the page is measured with its `[Fact]` run **alone** (`dotnet test <project> -c Release --filter "FullyQualifiedName~<TestName>"`), three times, with the range reported. A number read off a full-suite run is contaminated by xUnit's parallel collections and is not comparable to an isolated one — the same case has reported 983 ms in-suite against 1306-1402 ms isolated. See `Coding - Automatic Tests.md` §4.

---

## 4. Checklist: Adding a Benchmark

- [ ] Add `[Fact]` under `Facts/` in `<repo>.xUnit` using standard test rules.
- [ ] Expose sweep size as `const`/`static readonly` field at top of class.
- [ ] Implement warm-up call prior to `Stopwatch.StartNew()`.
- [ ] Add `Assert` statements verifying matching results between compared implementations.
- [ ] Execute test in **Release** build configuration, **filtered to that test alone**, three times; capture machine specs.
- [ ] Add/update `Benchmark.md` section: Title, test name, file, qualified signatures, knobs, result table, analysis.
- [ ] Commit, push to `master` on wiki clone, and verify link in `Home.md`.
