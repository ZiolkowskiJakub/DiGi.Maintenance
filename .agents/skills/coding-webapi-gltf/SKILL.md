---
name: coding-webapi-gltf
description: Use for tasks related to coding-webapi-gltf.
---

# Coding — WebAPI glTF

Standardized template and operational guide for any Visual Studio solution that integrates an
ASP.NET Core Web API with the `DiGi.GLTF` 3D visualization framework. Read this when creating a new
glTF-consuming Web API project, or when adding support for a new 3D object type to an existing one.

The reference implementation of everything described here is the pair
`DiGi.GLTF.WebAPI` (the generic engine) + `DiGi.GIS.WebAPI.UI` (a domain consumer).

---

## 1. Architectural blueprint

The system is a strictly decoupled 4-step pipeline. **Domain logic lives only in the consuming
project; rendering/glTF logic lives only in `DiGi.GLTF`.** The engine is never modified to add a new
domain type (Open-Closed Principle).

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ STEP 1 — Input data                (Consumer: DiGi.GIS.WebAPI.UI)                      │
│   ISerializableObject / IEnumerable<ISerializableObject>                               │
│   e.g. Building2D fetched from the GIS API or PostgreSQL.                              │
└───────────────────────────────────────────────┬───────────────────────────────────────┘
                                                 │
┌───────────────────────────────────────────────▼───────────────────────────────────────┐
│ STEP 2 — Domain-to-glTF conversion  (Consumer converters, dispatched by the engine)     │
│   IGLTFNodeConverter implementations turn a domain object into generic GLTFNode         │
│   instances (triangulated Mesh3D + Color + opacity + serialized properties), in         │
│   WORLD coordinates. Registered once; consulted by DiGi.GLTF.Convert.ToGLTF_GLTFNodes.  │
└───────────────────────────────────────────────┬───────────────────────────────────────┘
                                                 │
┌───────────────────────────────────────────────▼───────────────────────────────────────┐
│ STEP 3 — GLTFScene / ViewModel generation      (Engine: DiGi.GLTF)                      │
│   DiGi.GLTF.Create.GLTFScene merges the nodes, translates all geometry to a LOCAL       │
│   origin (0,0,0) and stores the removed world offset in GLTFScene.ReferencePoint,       │
│   then adds default lighting + an auto-framing camera. The consumer wraps this in a     │
│   thin ViewModel (title + streamed .glb URL).                                           │
└───────────────────────────────────────────────┬───────────────────────────────────────┘
                                                 │
┌───────────────────────────────────────────────▼───────────────────────────────────────┐
│ STEP 4 — WebGL UI view rendering    (Reusable engine JS + consumer host glue)           │
│   gltf-viewer-core.js (owned by DiGi.GLTF.WebAPI) fetches the batched binary .glb,       │
│   renders it (Revit navigation, marquee selection, frustum culling) and broadcasts      │
│   generic selection events. The consuming UI owns only the domain panels around it.     │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Why local-origin translation is mandatory

GIS coordinates are large (hundreds of thousands of meters). WebGL uses 32-bit floats, so rendering
raw world coordinates produces catastrophic vertex jitter. Step 3 subtracts a single reference point
from every vertex so the GPU only ever sees small numbers; the reference point is preserved in
`GLTFScene.ReferencePoint` (and in the `.glb` scene extras) to recover the original world position.

### Delivery: streamed, not inlined

The viewer page is a lightweight HTML shell carrying only a `data-glb-url`. Geometry is streamed
from a separate binary endpoint (`model/gltf-binary`); its scene extras carry a self-describing
`sceneConfiguration` (reference point, lights, camera) and an `objectMap` (per-object identity).
Never inline megabytes of base64 into the page.

---

## 2. New project onboarding checklist

The fastest path is the `dotnet new` template (see section 5). Do the steps below manually only when
integrating glTF into an existing project.

1. **Location.** Create the solution folder directly under the `DigiProject` workspace root:
   `DigiProject\<SolutionName>\<ProjectName>\`. The `DiGi.*` DLL references resolve by relative
   `HintPath` (`..\..\DiGi.Core\bin\...`), so the two-levels-up depth matters.

2. **Project SDK.** Use `Microsoft.NET.Sdk.Web`, `net10.0`, `<Nullable>enable</Nullable>`,
   `<LangVersion>latest</LangVersion>`, `<CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>`.

3. **References.** Add the generic engine and its geometry stack by `HintPath` (never a domain
   library — that would recouple the engine's consumer to domain code it does not need):

   ```xml
   <ItemGroup>
     <!-- NuGet dependencies of the referenced DLLs must be re-added on the exe/web project so
          they reach the output (HintPath references do not carry transitive NuGet packages). -->
     <PackageReference Include="NetTopologySuite" Version="2.6.0" />
     <PackageReference Include="SharpGLTF.Toolkit" Version="1.0.6" />
   </ItemGroup>

   <ItemGroup>
     <Reference Include="DiGi.Core">
       <HintPath>..\..\DiGi.Core\bin\DiGi.Core.dll</HintPath>
     </Reference>
     <Reference Include="DiGi.Geometry">
       <HintPath>..\..\DiGi.Geometry\bin\DiGi.Geometry.dll</HintPath>
     </Reference>
     <Reference Include="DiGi.GLTF">
       <HintPath>..\..\DiGi.GLTF\bin\DiGi.GLTF.dll</HintPath>
     </Reference>
   </ItemGroup>
   ```

4. **Bootstrap the generic controllers.** Register every converter of the project's assembly with
   the engine at startup, and enable response compression for the streamed payload:

   ```csharp
   using Microsoft.AspNetCore.ResponseCompression;

   WebApplicationBuilder webApplicationBuilder = WebApplication.CreateBuilder(args);

   webApplicationBuilder.Services.AddControllers();

   // The batched .glb JSON chunk (object properties) compresses very well.
   webApplicationBuilder.Services.AddResponseCompression(responseCompressionOptions =>
   {
       responseCompressionOptions.EnableForHttps = true;
       responseCompressionOptions.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(["model/gltf-binary"]);
   });

   // Plugin registration: scan this assembly for IGLTFNodeConverter implementations.
   DiGi.GLTF.Modify.Register(typeof(Program).Assembly);

   WebApplication webApplication = webApplicationBuilder.Build();
   webApplication.UseResponseCompression();
   webApplication.MapControllers();
   webApplication.Run();
   ```

5. **Expose an endpoint.** A generic endpoint accepts serialized DiGi objects and returns the
   batched `.glb`. The engine's registry resolves each object to `GLTFNode` instances:

   ```csharp
   [HttpPost("glb/fromobjects")]
   public IActionResult GLBFromObjects([FromBody] JsonArray? jsonArray, [FromQuery(Name = "name")] string? name = null)
   {
       if (jsonArray is null)
       {
           return BadRequest();
       }

       List<ISerializableObject>? serializableObjects = DiGi.Core.Create.SerializableObjects<ISerializableObject>(jsonArray);
       if (serializableObjects is null || serializableObjects.Count == 0)
       {
           return NoContent();
       }

       GLTFScene? gLTFScene = DiGi.GLTF.Create.GLTFScene(serializableObjects, name);
       if (gLTFScene is null)
       {
           return NoContent();
       }

       byte[]? bytes = DiGi.GLTF.Convert.ToSystem_Bytes(gLTFScene, true);
       if (bytes is null || bytes.Length == 0)
       {
           return NoContent();
       }

       return File(bytes, "model/gltf-binary", $"{gLTFScene.Name ?? "scene"}.glb");
   }
   ```

   > **Note on qualification.** Inside a project whose namespace is not under the `DiGi` root, the
   > DiGi innermost-enclosing-namespace lookup does not apply. Fully qualify the static classes:
   > `DiGi.GLTF.Create.GLTFScene(...)`, `DiGi.Core.Create.SerializableObjects<...>(...)`.

6. **Front-end (only if this project hosts the WebGL view).** Sync the reusable engine module into
   `wwwroot` at build time and load it through a versioned import map. See section 4.

---

## 3. Extensibility guide — adding a new 3D object type

**The rule:** supporting a new domain type requires **only a new converter class in the consuming
project**. Do not touch `DiGi.GLTF` or the generic controllers.

### 3.1 The abstraction

The engine exposes a plugin contract in `DiGi.GLTF`:

- `DiGi.GLTF.Interfaces.IGLTFNodeConverter` — `bool CanConvert(ISerializableObject)` +
  `List<GLTFNode>? Convert(ISerializableObject, double tolerance)`.
- `DiGi.GLTF.Classes.GLTFNodeConverter<TSerializableObject>` — convenience base for the common case
  of a single concrete type; you override the strongly-typed `Convert`.
- `DiGi.GLTF.Modify.Register(IGLTFNodeConverter?)` / `Register(Assembly?)` — registration; the
  assembly overload scans for all implementations with a public parameterless constructor.
- `DiGi.GLTF.Convert.ToGLTF_GLTFNodes(this ISerializableObject?, double)` — the dispatcher; consults
  registered converters (registration order, first `CanConvert` wins), then falls back to `GLTFNode`
  pass-through and raw `IGeometry3D` triangulation.

### 3.2 Template — a new converter

```csharp
using DiGi.GLTF.Classes;
using System.Collections.Generic;

namespace MyProject.Classes
{
    /// <summary>
    /// Converts a MyDomainObject into GLTFNode instances. Registered automatically at startup by
    /// assembly scanning (DiGi.GLTF.Modify.Register(typeof(Program).Assembly)).
    /// </summary>
    public class MyDomainObjectGLTFNodeConverter : GLTFNodeConverter<MyDomainObject>
    {
        public override List<GLTFNode>? Convert(MyDomainObject serializableObject, double tolerance)
        {
            // 1. EXTRACT the 3D geometry from the domain object. Convert 2D footprints to 3D and
            //    extrude if required. Keep coordinates in WORLD space — the local-origin shift
            //    happens later, once, for the whole scene.
            DiGi.Geometry.Spatial.Interfaces.IGeometry3D? geometry3D = serializableObject.Geometry;
            if (geometry3D is null)
            {
                return null;
            }

            // 2. STYLE. Pick a color and opacity (opacity < 1 => the object joins the blended batch).
            DiGi.Core.Classes.Color color = new(byte.MaxValue, 222, 184, 135);
            double opacity = 1.0;

            // 3. IDENTITY + PROPERTIES. A stable reference is broadcast on selection; the serialized
            //    source object becomes the properties payload shown in the viewer.
            string? reference = DiGi.Core.Create.UniqueReference(serializableObject)?.ToString();
            string? properties = DiGi.Core.Convert.ToSystem_String(serializableObject);

            // 4. PACK into a generic GLTFNode. The engine triangulates the geometry into a Mesh3D.
            GLTFNode? gLTFNode = DiGi.GLTF.Create.GLTFNode(
                geometry3D, serializableObject.GetType().Name, reference, color, opacity, properties, tolerance);
            if (gLTFNode is null)
            {
                return null;
            }

            return [gLTFNode];
        }
    }
}
```

That is the entire change. On next startup the assembly scan finds and registers it, and every
generic endpoint immediately supports `MyDomainObject`.

### 3.3 Worked example — a 2D footprint extruded to 3D (the `Building2D` pattern)

This is the canonical GIS case: take a 2D polygonal face, lift it onto a horizontal plane, extrude
it by the number of storeys, and pack it — again, all in world coordinates.

```csharp
public override List<GLTFNode>? Convert(Building2D serializableObject, double tolerance)
{
    PolygonalFace2D? polygonalFace2D = serializableObject.PolygonalFace2D;
    if (polygonalFace2D is null)
    {
        return null;
    }

    // 2D footprint -> 3D face on the ground plane (Z = 0).
    Plane? plane = DiGi.Geometry.Spatial.Create.Plane(0);
    PolygonalFace3D? polygonalFace3D = plane.Convert(polygonalFace2D);
    if (polygonalFace3D is null)
    {
        return null;
    }

    // Extrude by storeys * storey height.
    int storeys = serializableObject.Storeys < 1 ? 1 : serializableObject.Storeys;
    PolygonalFaceExtrusion polygonalFaceExtrusion = new(polygonalFace3D, new Vector3D(0, 0, storeys * 3.0));

    string? reference = serializableObject.Reference ?? DiGi.Core.Create.UniqueReference(serializableObject)?.ToString();

    GLTFNode? gLTFNode = DiGi.GLTF.Create.GLTFNode(
        polygonalFaceExtrusion, $"Building2D {reference}", reference,
        new DiGi.Core.Classes.Color(byte.MaxValue, 222, 184, 135), 1,
        DiGi.Core.Convert.ToSystem_String(serializableObject), tolerance);

    return gLTFNode is null ? null : [gLTFNode];
}
```

### 3.4 Handling large GIS coordinates — do NOT do it in the converter

The reference-point translation is a **scene-level** concern, applied exactly once by
`DiGi.GLTF.Create.GLTFScene`. A converter must emit world coordinates and nothing else. Emitting
pre-shifted coordinates from a converter would double-shift the scene and corrupt multi-object
alignment. The offset is available afterwards as `GLTFScene.ReferencePoint`.

### 3.5 Matching against an interface instead of a concrete type

When the domain match is an interface (e.g. any `IComponent`), implement `IGLTFNodeConverter`
directly rather than the generic base, and test with `is`:

```csharp
public class ComponentGLTFNodeConverter : DiGi.GLTF.Interfaces.IGLTFNodeConverter
{
    public bool CanConvert(ISerializableObject serializableObject) => serializableObject is IComponent;

    public List<GLTFNode>? Convert(ISerializableObject serializableObject, double tolerance)
    {
        if (serializableObject is not IComponent component)
        {
            return null;
        }
        // ... extract surface geometry, pack into GLTFNode(s) ...
    }
}
```

Register more specific converters before more general ones — the first matching converter wins.

---

## 4. Performance & optimization requirements

These are strict rules for any project rendering more than a handful of objects.

### 4.1 Geometry batching / merging (backend, mandatory for large datasets)

Thousands of individual glTF nodes = thousands of WebGL draw calls = a frozen browser. The engine
merges all node geometry into **one draw unit per alpha mode** (opaque + blended) via
`DiGi.GLTF.Create.GLTFBatches`, invoked automatically by `ToSystem_Bytes(gLTFScene, batched: true)`.
Per-object color is baked into the vertex `COLOR_0` attribute, so objects do **not** need to share a
material to share a draw call. **Always pass `batched: true` for multi-object scenes.**

Result at reference scale: 15,704 buildings / 265k triangles render in **4 draw calls at ~59 FPS**.

### 4.2 ID mapping for raycasting (backend + frontend)

Merged geometry loses per-node identity, so identity is re-encoded:

- Every vertex carries its object id in a custom `_OBJECTID` float vertex attribute.
- Each object occupies a **contiguous** vertex/index range, recorded in an `objectMap` array written
  to the glTF scene extras (array index == object id == the value in `_OBJECTID`).

The frontend decodes the `_OBJECTID` of the raycast-hit face to resolve the exact object, and
highlights it by tinting only its contiguous vertex-color range (uploading just that sub-range to the
GPU). This keeps selection O(range), independent of scene size.

### 4.3 Asynchronous frontend loading (frontend, mandatory)

- **Stream the binary `.glb`** from an endpoint (`fetchGlbBytes(url)`); never inline base64 into the
  page. The page shell must stay in the low-KB range regardless of scene size.
- **Never block the main thread.** The GLB is fetched as raw binary; `GLTFLoader.parse` consumes it
  zero-copy; heavy structures (edge overlays, the raycast BVH) are built *after* the first frame is
  presented (`setTimeout(..., 0)`), so the UI never freezes on load.
- **Raycast acceleration.** `three-mesh-bvh` is loaded via the import map with a graceful fallback:
  without it, hover picking is throttled so the frame rate stays stable.

### 4.4 Frustum culling (frontend)

All meshes are marked `frustumCulled = true` with computed bounding boxes/spheres, so geometry
outside the viewport is skipped by the renderer.

### 4.5 Reusable viewer engine delivery

The engine JS (`gltf-viewer-core.js`) is owned by `DiGi.GLTF.WebAPI/wwwroot/js/`. A consuming UI syncs
it into its own `wwwroot` at build time (the static-asset analogue of the `HintPath` DLL references)
and imports it through a versioned import map:

```xml
<Target Name="CopyGLTFViewerCore" BeforeTargets="Build">
  <Copy SourceFiles="$(ProjectDir)..\..\DiGi.GLTF.WebAPI\DiGi.GLTF.WebAPI\wwwroot\js\gltf-viewer-core.js"
        DestinationFolder="$(ProjectDir)wwwroot\js\" SkipUnchangedFiles="true" />
</Target>
```

The engine dispatches generic events on its container — `gltf-ready` (`{ objectCount, referencePoint,
name }`) and `gltf-selectionchanged` (`{ references: string[] }`) — and exposes a small API
(`frameScene`, `clearSelection`, `getUserData`, `setSun`, ...). **The consuming UI owns only the
domain panels** (properties, lighting) and reacts to these events; it never forks the engine.

> **Import map + tag helpers gotcha.** With MVC tag helpers active, the `<script type="importmap">`
> element is rewritten and the `type` attribute is stripped, breaking module resolution. Opt that one
> element out with the Razor `!` prefix: `<!script type="importmap"> ... </!script>`.

---

## 5. Visual Studio solution template

To scaffold a ready-to-run generic host pre-configured with the engine references, response compression, plugin registration hooks, and sample converter, use the template located in the default `templates/` directory.

Detailed installation, usage scenarios, and command guidelines for this template are documented in the central [Coding - Templates.md](Coding%20-%20Templates.md) guideline.

---

## Checklist summary

- [ ] Solution folder under `DigiProject\` root (two levels above the DLL `HintPath`s).
- [ ] References: `DiGi.Core`, `DiGi.Geometry`, `DiGi.GLTF` (never a domain library on the engine host).
- [ ] Re-add transitive NuGet packages (`NetTopologySuite`, `SharpGLTF.Toolkit`, plus `Npgsql` etc. if used).
- [ ] `DiGi.GLTF.Modify.Register(typeof(Program).Assembly)` at startup.
- [ ] One `IGLTFNodeConverter` per new domain type — no engine or controller edits.
- [ ] Converters emit world coordinates; never pre-shift (scene handles the reference point).
- [ ] `ToSystem_Bytes(scene, batched: true)` for multi-object scenes.
- [ ] Stream the `.glb`; keep the page a thin shell; enable response compression.
- [ ] Runtime secrets (e.g. a PostgreSQL `*.conf` for a direct-DB endpoint) go in the git-ignored
      `user files/`, never the committed `files/` — see the `files/` vs `user files/` rule in
      `Coding - General.md`.
- [ ] No `var`; explicit types; English only.

