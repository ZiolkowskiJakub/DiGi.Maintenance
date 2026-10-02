---
name: coding-geometry
description: "Use when orienting, closing, triangulating, hashing or sweeping DiGi.Geometry / DiGi.Solar geometry - SunDirection is a propagation vector (negate before dotting with a normal), Vector3D.Unit never returns null, cosine not via Angle, asymmetric orientation fixtures, IsClosed is not monotonic in tolerance, sub-tolerance corners before Triangulate, spatial hash keys (round, mix sequentially), PolygonalFace2DPointRelationSolver for point sweeps."
---

# AI Guidelines: Geometry & Solar Conventions (`DiGi.Geometry`, `DiGi.Solar`)

**Goal:** Conventions and traps of the DiGi geometry stack that the type signatures do not show. Every
item below once produced a **plausible wrong answer rather than an error** — an inverted physics result,
a guard that never fires, a test that passes on fixtures too symmetric to notice. Read this before
writing or reviewing code that orients, closes, triangulates, hashes or sweeps geometry.

General C# rules still apply (`Coding - General.md`); geometry primitives keep their interface-contract
instance methods (`Coding - General.md` §2 *Interface Contract Exception*).

---

## 1. Vectors and Directions

- **`DiGi.Solar.Query.SunDirection` is a propagation vector — it points AWAY from the sun.** It is
  `-(cos el·sin az, cos el·cos az, sin el)`, so `z = -sin(elevation)` points **down while the sun is up**.
  The incidence cosine on a surface is therefore `cos θ = -(s.Unit · n.Unit)`, not `s · n`. Implemented
  as `s · n` (as DiGi.Solar#1 specified), every lit surface scores zero beam irradiance and every surface
  facing away lights up — and a fact asserting only `Length == 1` passes for either sign. Pin the
  convention with a fact that feeds **real** `SunDirection` output
  (`IrradianceResult_SunDirectionConvention` in `DiGi.Solar.xUnit`); a hand-written vector tests your
  arithmetic, not the convention. Frame: X = East, Y = North, Z = Up — a south-facing wall normal is
  `(0, -1, 0)`.
- **`Vector3D.Unit` never returns `null`**, although it is declared `Vector3D?` and documented "or null". A
  zero vector comes back as a non-null degenerate vector, so `if (v.Unit == null) return null;` never fires
  — a `(0,0,0)` normal went through `Create.IrradianceResult` as a 0° tilt and produced a full-sky result.
  Guard on the length **before** normalizing:
  `if (v == null || double.IsNaN(v.Length) || v.Length <= 0) return null;`.
- **`Vector3D.Angle` returns `0`, not `NaN`, for a zero vector**, so it cannot serve as a degeneracy test
  either.
- **Never compute a cosine through `Angle`.** `Math.Cos(v.Angle(WorldZ))` for a unit vector is `v.Z`, but
  the `acos` → `cos` round trip is ill-conditioned at the ends of its range: a vertical surface returns
  `6.12e-17` instead of `0`. Take the dot product or the ordinate directly; call `Angle` only when you want
  an angle.

## 2. Orientation and Normalisation

- **Test orientation with asymmetric fixtures — a rectangle cannot fail.** Until DiGi.Geometry#6,
  `Planar.Flip` turned the plane and left `geometry2D` alone, mirroring every face it flipped about the
  plane's X axis (a wall dropped a storey, a floor moved 700 km). It survived because `Create.Plane(points)`
  puts the origin at the centroid and a rectangle maps onto itself under a mirror through its centre, so
  every box and courtyard fixture passed. Use a trapezoid, a gable pentagon, an L-shaped floor or a real
  swept wall, and assert invariants independent of the code under test: every ring keeps its 3D points
  after orienting, shared edges run in opposite directions, the signed volume is positive
  (`DiGi.Geometry.xUnit/Facts/Flip.cs`, `BuildingModelGetExternalShell_*` on
  `DiGi.Test/files/BuildingModel_Envelope.json`).
- **A face normal is `Plane.Normal`; ring winding is separate** and, after a turn, runs against the normal.
  A consumer deriving triangle winding (glTF) passes `Orientation.CounterClockwise, Orientation.Clockwise`
  explicitly rather than assuming the two agree.

## 3. Closure and Tolerance

- **`Spatial.Query.IsClosed(polyhedron, tolerance)` is not monotonic in `tolerance`.** Raising it does not
  only forgive gaps: welding merges vertices meant to stay apart, edges collapse, and the even-count parity
  that decides closure breaks. Stored `BuildingModel`s close at `1e-6` and report **open** at `0.05`, within
  the first 20 000 sampled.
- **"Enclosed at tolerance T" therefore means "closes at some tolerance ≤ T".** Walk an ascending ladder and
  take the first value that closes; that value is also the useful diagnostic (slightly imprecise source vs
  never a solid). `DiGi.Analytical.Building/Query/IsEnclosed.cs` and
  `DiGi.GIS.Analytical`'s `BuildingModelValidationResult` do this. Judge manifoldness
  (`IsClosed(manifold: true, …)`) at the tolerance the shell actually closes at.

## 4. Triangulation

- **`Planar.Query.Triangulate(Polygon?, double)` recursed forever on corners closer than the tolerance.**
  It builds its `GeometryFactory` with `PrecisionModel(1 / tolerance)`; sub-tolerance corners collapse onto
  one grid point, the clip returns the polygon unchanged, and the recursion never progresses. The result is
  a `StackOverflowException`, which **cannot be caught**: the process dies with `0xC00000FD`, no log line
  and no error page — a web host just drops the connection. A guard at the recursion site now drops a
  no-progress piece (a small area loss, not a fix). **Drop consecutive corners within the tolerance before
  calling it** — copy the `Clean` local function of `Spatial.Query.Difference(Mesh3D, …)`. Real trigger:
  cutting several building outlines out of one terrain triangle at PL-1992 magnitudes; fixture
  `Triangulate_SubToleranceCorners`.
- **Check NetTopologySuite before writing a geometry algorithm.** It is already referenced, and its shipped
  `NetTopologySuite.xml` lists every type. `Triangulate.Polygon.PolygonTriangulator` (ear clipping with
  holes) is the general polygon triangulator; `ConformingDelaunayTriangulationBuilder` is not
  (`Coding - General.md` §4).

## 5. Spatial Hash Keys

Both traps below keep the answer **correct but slow** — a collision or a split key only demotes work to a
slower path — so they pass review and unit tests and show up only as an unexplained constant factor.

- **Round the cell index, do not floor it, when the key must group identical points.**
  `(long)Math.Floor(v * invTolerance)` puts a cell boundary on every multiple of the tolerance, which is
  exactly where clean geometry sits: a face at `z = 0` whose neighbour reprojects to `-1e-16` lands one cell
  lower. Rounding moves the boundary to the half-cell. A grid used for **neighbour probing** keeps `Floor`
  and probes the surrounding cells.
- **Mix ordinates one at a time — each exclusive-or immediately followed by a multiply.** Over the 1 500
  edge keys of a 500-gon extrusion, `(x*A) ^ (y*B) ^ (z*C)` collided 108 times, `((x ^ y) * K1) ^ z` 694 times
  (exclusive-or is symmetric and a regular polygon carries vertices with swapped ordinates), and an
  FNV-1a sequence with a murmur avalanche 0 times:

  ```csharp
  ulong hash = 0xCBF29CE484222325UL;
  hash = (hash ^ (ulong)(long)Math.Round(x * invTolerance)) * 0x100000001B3UL;   // repeat for y, z
  hash ^= hash >> 33; hash *= 0xFF51AFD7ED558CCDUL; hash ^= hash >> 33;
  ```
- **Detect either by histogramming bucket sizes** against an exact tuple key
  (`Dictionary<(long, long, long), …>`). Clean geometry gives buckets of exactly the expected multiplicity.

## 6. Hot Loops

- **Many points against one polygon: use `Planar.Classes.PolygonalFace2DPointRelationSolver`.** Build one
  per polygon, then `Input = point; Solve(); Output == PointRelation.Inside`. Warsaw's 4 260-point outline
  against 155 000 points takes 25 ms, versus 1 655 ms for `PolygonalFace2D.Inside`. Same semantics
  (boundary within tolerance is `On`, holes excluded); not thread-safe (scratch buffer) — one per thread.
- **Copy coordinates out of `List<Point2D>` before a hot loop.** `Point2D.X` is `values[0]` on a heap
  `double[]`, so every edge test costs two pointer chases per vertex (~14 ns per edge against ~2.4 ns over a
  flat `double[]`).
- **Write parity facts against the library before trusting a "same semantics" claim** — they surfaced a
  pre-existing `PolygonalFace2D.InRange` bug (the outline's `On` answer was dropped when the face had holes).
  Benchmarking rules are in `Coding - Automatic Tests.md` §4.

## 7. Checklist

- [ ] Sun or light direction negated before dotting with a normal?
- [ ] Zero-length guard on `Length`, not on `Unit == null` or `Angle`?
- [ ] Orientation/normalisation facts include an asymmetric face?
- [ ] Closure checked as "closes at some tolerance ≤ T", not `IsClosed(T)`?
- [ ] Sub-tolerance corners removed before `Triangulate`?
- [ ] Exact-grouping hash keys rounded, ordinates mixed sequentially, buckets histogrammed?
- [ ] Point sweeps through `PolygonalFace2DPointRelationSolver`, coordinates flattened in hot loops?
