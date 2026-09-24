# AI Guidelines: ComputeSharp Compute Shaders

Rules for writing or changing an `IComputeShader` struct (ComputeSharp 3.2, D3D12) — today all of them live in
`DiGi.ComputeSharp`. A shader that runs, returns the right shape and raises no error can still be computing
garbage; everything below exists because that happened.

## Mandatory Rule

> **A shader must not have an odd number of 32-bit root constants AND an odd number of bound resources.
> Prefer an even root constant count (`ConstantBufferSize` a multiple of 8) for every new shader.**

---

## 1. How ComputeSharp Lays Out The Constant Buffer

Every value field of the shader struct (everything that is not a `ReadOnlyBuffer`/`ReadWriteBuffer`/texture) goes
into one constant buffer, which ComputeSharp binds as **32-bit root constants**
(`Num32BitValues = ConstantBufferSize / 4`). The buffers are the shader's *resources* — one descriptor range each.

- **Bytes 0–11** hold the dispatch header `__x`, `__y`, `__z`. Your fields start after it.
- **Offset 12** is a free 4-byte slot. A 4-byte field (`int`, `float`, `Bool`) declared *first* lands there at no cost.
- A `double` is 8-byte aligned (the first one lands at 16). A struct field (`Coordinate3`, `Line2`, `Triangle3`)
  starts on the next 16-byte row.
- **Declaration order is layout order** — for a primary-constructor struct, the order of the captured parameters.
  Moving a field changes `ConstantBufferSize`.
- The HLSL `cbuffer` size DXC records equals `ConstantBufferSize` (it is not padded to 16 in the metadata), and
  ComputeSharp does **not** embed a root signature in the DXIL — it builds one at run time from the descriptor.

**Read the layout, don't compute it.** Either build with
`-p:EmitCompilerGeneratedFiles=true -p:CompilerGeneratedFilesOutputPath=<dir>` and read `ConstantBufferSize =>` and
the `[FieldOffset]`s in the generated `*.g.cs`, or read it from code — the generated descriptor exposes static
members, so no graphics device is needed:

```csharp
public static int ConstantBufferSize<T>() where T : struct, IComputeShader, IComputeShaderDescriptor<T>
{
    return T.ConstantBufferSize; // also: T.ResourceDescriptorRanges, T.HlslSource, T.HlslBytecode
}
```

## 2. The Odd/Odd Driver Defect (DiGi.ComputeSharp#3)

On NVIDIA GeForce RTX 5090, driver 617.14, a shader whose root constant count **and** resource count
(SRVs + UAVs) are both odd returns **wrong double-precision results for every thread**, with no exception and no
device removal (also with the D3D12 debug layer enabled). Measured with a ~40-line shader (cross product → Newton `Sqrt` →
normalize → dot product), the extra field **never read**:

| Root constants | Resources (SRV + UAV) | RTX 5090 | WARP |
|---|---|---|---|
| even (10, 12, 14, 16, 18) | any (1–6) | correct | correct (14, 16 with 2–3 resources) |
| odd (11, 13, 15, 17, 33) | even (2, 4, 6) | correct | correct (15 with 2 resources) |
| odd (11, 13, 15, 17) | odd (1, 3, 5) | **wrong** | correct (15 with 3 resources) |

- **The DXIL of a failing and a working shader is identical** apart from the cbuffer size metadata (56 → 60 B), and
  WARP computes both correctly — the fault is in the driver's DXIL-to-native compilation, not in DXC or ComputeSharp.
- **The inputs arrive intact.** Echoing the constants and buffer values from the failing thread returns them
  correctly; it is the arithmetic on them that comes back as a denormal or `0` (`vector · normal` =
  `-1.5E-323` instead of `-0.9995…`).
- **A trivial body does not trigger it.** A shader that only sums its constants and buffer values was correct at
  15 constants and 3 resources — so a quick smoke shader proves nothing about the layout. Only the rule does.

**Fix a layout by reordering or padding, never by dropping a resource.** Put a 4-byte field first (offset 12), or
add one unused `int` to reach an even count. `Triangle3ExternalShadingRowOffsetComputeShader` declares
`int rowOffset` first — 56 B / 14 constants, the exact layout of `Triangle3ExternalShadingComputeShader`; appended,
it was 60 B / 15 constants with 3 resources and returned zero hits where the CPU found five.

This field order is a **permanent** layout choice, not a workaround to be reverted, so it carries no
`TODO [Marker]` (`Coding - General.md` §1.12).

## 3. A Layout Change Needs A Guard And A Parity Fact

- **The guard:** `DiGi.Test/DiGi.ComputeSharp.xUnit/Facts/ComputeShader_ConstantBufferLayout.cs` enumerates every
  `IComputeShader` in `DiGi.ComputeSharp`, fails on the odd/odd combination, and pins each shader's
  `ConstantBufferSize` and resource count. A new shader, or any field added, removed or moved, fails it until the
  table is updated — which is the point: the change is made deliberately. It needs no GPU.
- **The parity fact:** a new or re-laid-out shader is compared **cell for cell** with a proven shader or the CPU
  reference (the row-offset facts compare each new struct with its old counterpart for two directions and two
  tolerances). A fact that compares a shader only with itself cannot see a layout defect.
- **Proving the guard** (`Coding - Automatic Tests.md` §4 "A Guard Must Be Shown To Fail"): move the field, watch the
  guard fail, restore. On #3, moving `rowOffset` last failed both the guard and the GPU parity fact; padding it to
  64 B failed only the pinned size, and the parity fact passed — consistent with the rule.

## 4. GPU Fact Conventions

- **Gate on the device:** `if (!Query.IsComputeSharpSupported(testOutputHelper)) { return; }` — the suite must run
  on machines without an FP64-capable GPU.
- **Catch `UnsupportedDoubleOperationException`** by type name and write a warning rather than failing.
- **Assert the scenario is not vacuous:** a mix of hits and misses (`nonNaN > 0 && nonNaN < count`). An all-NaN
  result compared with another all-NaN result passes every equality check — which is exactly what the #3 defect
  produces.
- **Keep layout facts GPU-free** where possible (§1's static descriptor members), so they run everywhere.

## 5. Probing A Suspected GPU Defect

- **Compare against WARP — on a reduced shader** — `GraphicsDevice.QueryDevices(info => !info.IsHardwareAccelerated).First()`
  splits a driver fault from a DXC/ComputeSharp one. Reduce first: WARP needed about 20 minutes for one dispatch of
  the ~90 k-character intersection routine, and it is **not a trustworthy reference for that routine** — it returned
  0 hits for the proven 56-byte `Triangle3ExternalShadingComputeShader` where the CPU and the RTX 5090 found 5
  (unexplained at the time of writing). On the reduced repro it agreed with the CPU for every layout.
- **Diff the DXIL:** write `T.HlslBytecode` to disk and run `dxc.exe -dumpbin` (Windows SDK) on both variants.
  Identical instructions plus different results means the driver.
- **Echo before you bisect:** write the constants and inputs back out from the failing thread; if they are right,
  the defect is in the arithmetic, and a stage-by-stage bisection of the body finds the smallest failing piece.
- **Debug layer:** set the MSBuild property `ComputeSharpEnableDebugOutput=true`. Messages go to the Windows debug
  output stream, not the console — a clean console is not a clean validation.
- **Mutation-test mtime trap:** restoring a file with `cp`/`mv` keeps an mtime older than the mutated build, so the
  next incremental build skips it and the mutant stays live. `touch` the file or rebuild with `--no-incremental`
  (`dotnet test` rejects that switch — `dotnet build --no-incremental`, then `dotnet test --no-build`).
