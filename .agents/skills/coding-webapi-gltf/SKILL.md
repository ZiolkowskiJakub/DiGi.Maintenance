---
name: coding-webapi-gltf
description: "Use when building or extending an ASP.NET Core Web API on the DiGi.GLTF 3D framework - the decoupled pipeline, onboarding a new consuming project, adding a 3D object type via IGLTFNodeConverter, batching/streaming performance rules, the git-tracked gltf-viewer-core.js copy (commit both repositories), and what the batched payload does not carry (no NORMAL attribute, inconsistent winding, on-change shadow map contract)."
---

# Coding — WebAPI glTF

Standardized guide for integrating ASP.NET Core Web APIs with the `DiGi.GLTF` 3D visualization framework (reference: `DiGi.GLTF.WebAPI` engine + `DiGi.GIS.WebAPI.UI` consumer).

---

## 1. Architectural Blueprint

4-step decoupled pipeline:
1. **Input Data (Consumer):** `ISerializableObject` collection (e.g., `Building2D` from DB/GIS).
2. **Domain-to-glTF Conversion (Consumer Converters):** `IGLTFNodeConverter` converts domain objects into generic `GLTFNode` instances in **WORLD coordinates**. Registered at startup; dispatched by `DiGi.GLTF`.
3. **`GLTFScene` Generation (Engine):** `DiGi.GLTF.Create.GLTFScene` merges nodes, shifts geometry to a **LOCAL origin (0,0,0)** (storing removed world offset in `GLTFScene.ReferencePoint`), and adds lighting/camera.
4. **WebGL View Rendering (Engine JS + Consumer Host):** `gltf-viewer-core.js` fetches binary `.glb`, renders, and broadcasts selection events.

### Critical Rules
- **Local Origin Translation:** Mandatory. WebGL 32-bit floats jitter on raw GIS world coordinates. `GLTFScene` subtracts `ReferencePoint` so GPU sees small numbers.
- **Streamed Delivery:** Stream geometry as binary `.glb` (`model/gltf-binary`). Never inline base64 into HTML.

---

## 2. New Project Onboarding Checklist

1. **Location:** Create solution folder directly under workspace root (`workspace_root\<Solution>\<Project>\`) to preserve 2-level relative `HintPath`s (`..\..\DiGi.Core\bin\...`).
2. **Project Config:** SDK `Microsoft.NET.Sdk.Web`, `net10.0`, `<Nullable>enable</Nullable>`, `<LangVersion>latest</LangVersion>`, `<CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>`.
3. **References:** Add `NetTopologySuite`, `SharpGLTF.Toolkit`, and `HintPath` references to `DiGi.Core`, `DiGi.Geometry`, `DiGi.GLTF`.
4. **Startup Bootstrap:** Configure response compression and register converters:
   ```csharp
   using Microsoft.AspNetCore.ResponseCompression;

   WebApplicationBuilder builder = WebApplication.CreateBuilder(args);
   builder.Services.AddControllers();
   builder.Services.AddResponseCompression(options =>
   {
       options.EnableForHttps = true;
       options.MimeTypes = ResponseCompressionDefaults.MimeTypes.Concat(["model/gltf-binary"]);
   });

   // Scan assembly for IGLTFNodeConverter implementations
   DiGi.GLTF.Modify.Register(typeof(Program).Assembly);

   WebApplication app = builder.Build();
   app.UseResponseCompression();
   app.MapControllers();
   app.Run();
   ```
5. **Endpoint Contract:**
   ```csharp
   [HttpPost("glb/fromobjects")]
   public IActionResult GLBFromObjects([FromBody] JsonArray? jsonArray, [FromQuery(Name = "name")] string? name = null)
   {
       if (jsonArray is null) return BadRequest();
       List<ISerializableObject>? objects = DiGi.Core.Create.SerializableObjects<ISerializableObject>(jsonArray);
       if (objects is null || objects.Count == 0) return NoContent();

       GLTFScene? scene = DiGi.GLTF.Create.GLTFScene(objects, name);
       if (scene is null) return NoContent();

       byte[]? bytes = DiGi.GLTF.Convert.ToSystem_Bytes(scene, true); // batched: true
       if (bytes is null || bytes.Length == 0) return NoContent();

       return File(bytes, "model/gltf-binary", $"{scene.Name ?? "scene"}.glb");
   }
   ```
6. **Frontend Asset:** Copy `gltf-viewer-core.js` into `wwwroot/js/` at build time.

---

## 3. Extensibility Guide — Adding a 3D Object Type

To support a new domain object type, **create a new converter class in the consuming project**. Do NOT modify `DiGi.GLTF` or core controllers.

### 3.1 Concrete Type Converter Template

```csharp
using DiGi.GLTF.Classes;
using System.Collections.Generic;

namespace MyProject.Classes
{
    public class MyDomainObjectGLTFNodeConverter : GLTFNodeConverter<MyDomainObject>
    {
        public override List<GLTFNode>? Convert(MyDomainObject serializableObject, double tolerance)
        {
            // 1. Extract 3D geometry in WORLD coordinates (do not shift origin)
            DiGi.Geometry.Spatial.Interfaces.IGeometry3D? geometry3D = serializableObject.Geometry;
            if (geometry3D is null) return null;

            // 2. Styling, Reference, Properties
            DiGi.Core.Classes.Color color = new(byte.MaxValue, 222, 184, 135);
            string? reference = DiGi.Core.Create.UniqueReference(serializableObject)?.ToString();
            string? properties = DiGi.Core.Convert.ToSystem_String(serializableObject);

            // 3. Pack into GLTFNode
            GLTFNode? node = DiGi.GLTF.Create.GLTFNode(
                geometry3D, serializableObject.GetType().Name, reference, color, 1.0, properties, tolerance);

            return node is null ? null : [node];
        }
    }
}
```

### 3.2 2D Footprint Extrusion Pattern (`Building2D`)

```csharp
public override List<GLTFNode>? Convert(Building2D serializableObject, double tolerance)
{
    PolygonalFace2D? face2D = serializableObject.PolygonalFace2D;
    if (face2D is null) return null;

    Plane plane = DiGi.Geometry.Spatial.Create.Plane(0);
    PolygonalFace3D? face3D = plane.Convert(face2D);
    if (face3D is null) return null;

    int storeys = serializableObject.Storeys < 1 ? 1 : serializableObject.Storeys;
    PolygonalFaceExtrusion extrusion = new(face3D, new Vector3D(0, 0, storeys * 3.0));

    string? reference = serializableObject.Reference ?? DiGi.Core.Create.UniqueReference(serializableObject)?.ToString();

    GLTFNode? node = DiGi.GLTF.Create.GLTFNode(
        extrusion, $"Building2D {reference}", reference,
        new DiGi.Core.Classes.Color(byte.MaxValue, 222, 184, 135), 1.0,
        DiGi.Core.Convert.ToSystem_String(serializableObject), tolerance);

    return node is null ? null : [node];
}
```

### 3.3 Converter Constraints
- **WORLD Coordinates:** Converters MUST emit world coordinates. Origin translation is applied at scene level (`GLTFScene`). Pre-shifting inside converters causes double-shift bugs.
- **Interface Matching:** To match interfaces, implement `IGLTFNodeConverter` directly and test with `is`:
  ```csharp
  public class ComponentGLTFNodeConverter : IGLTFNodeConverter
  {
      public bool CanConvert(ISerializableObject obj) => obj is IComponent;
      public List<GLTFNode>? Convert(ISerializableObject obj, double tolerance) { ... }
  }
  ```

---

## 4. Performance & Optimization

- **Geometry Batching:** Mandatory for large datasets. Call `ToSystem_Bytes(scene, batched: true)`. Merges node geometries into one draw unit per alpha mode (opaque/blended) using vertex `COLOR_0`.
- **ID Raycast Mapping:** Every vertex carries object ID in `_OBJECTID` float attribute. Contiguous vertex ranges are recorded in scene extras `objectMap`. Frontend selection highlights by updating GPU vertex color range in O(range) time.
- **Async Loading:** Stream binary `.glb`; parse zero-copy; build BVH/edges asynchronously post-first-frame (`setTimeout(..., 0)`).
- **Frustum Culling:** Set `frustumCulled = true` on all meshes.
- **Engine JS Deployment:** Sync viewer JS via MSBuild target:
  ```xml
  <Target Name="CopyGLTFViewerCore" BeforeTargets="Build">
    <Copy SourceFiles="$(ProjectDir)..\..\DiGi.GLTF.WebAPI\DiGi.GLTF.WebAPI\wwwroot\js\gltf-viewer-core.js"
          DestinationFolder="$(ProjectDir)wwwroot\js\" SkipUnchangedFiles="true" />
  </Target>
  ```
  Opt out Razor importmap rewriting using `<!script type="importmap">`.
  The copy in the consumer is **git-tracked**: an engine change is committed in `DiGi.GLTF.WebAPI`
  *and* in every consumer whose build refreshed the copy. The target runs `BeforeTargets="Build"`,
  after `CoreBuild` — a build that fails on a locked `bin\*.exe` (an instance still running) never
  reaches it, so confirm the two files hash-identical before committing the consumer.

---

## 5. What the batched payload does NOT carry — consumer-side facts

Learned on DiGi.GIS.WebAPI.UI#43, where the engine's shade had never rendered in any scene while
every flag said it did.

- **No `NORMAL` attribute.** `GLTFLoader` compensates with `material.flatShading = true`, so lighting
  comes from screen-space derivatives and looks right. Any shader path that reads the vertex normal
  gets the all-zero default attribute: three.js's shadow receiver normalises it for the `normalBias`
  offset, `normalize(vec3(0))` is NaN, and every fragment fails the shadow-frustum test — lit
  everywhere, whatever the bias. A populated depth map proves nothing about the receivers.
- **Consistent triangle winding** (since DiGi.GLTF#1). Terrain is up-facing (+Z): `Mesh3D.Difference`
  normalises the cut remainder, and the height field was already up-facing. Building envelopes come
  from `BuildingModel.GetExternalShell(Side.External, ...)` and are outward-consistent: on the
  reference scene 18 077 shared edges are traversed in opposite directions by their two faces and 6
  in the same direction, all 6 on the two open envelopes (storey-split T-junctions, see
  DiGi.Analytical#3). The winding is safe to use: `FrontSide` and `DoubleSide` render the reference
  scene identically (79 of 469 260 pixels differ, antialiasing on the open-envelope silhouettes) and
  winding-derived normals are correctly oriented. Mind that three.js renders the depth map from the
  *opposite* side when `material.shadowSide` is null, so switching `side` also moves every shade
  edge by the bias unless `shadowSide` is pinned. Slivers survive: a few dozen terrain triangles of
  area below 0.001 m² carry a numerically random sign — filter by area before counting.
- **Engine shade contract** (`gltf-viewer-core.js`): `renderer.shadowMap.autoUpdate = false`; the
  shadow camera is anchored to the scene centre and does not follow the view camera, so the depth
  map is rendered on change only. Any new mutation that changes what casts shade (a new caster
  type, a visibility filter, a clipping change) must call `requestShadowUpdate()`. The shadow-bias
  normals are computed once from the winding and averaged per vertex (`prepareShadowNormals`) — no
  per-sun re-orientation is needed.

---

## 6. Checklist Summary

- [ ] Solution folder placed under workspace root (`workspace_root\<Solution>\`).
- [ ] References set: `DiGi.Core`, `DiGi.Geometry`, `DiGi.GLTF`, `NetTopologySuite`, `SharpGLTF.Toolkit`.
- [ ] Startup includes `DiGi.GLTF.Modify.Register(typeof(Program).Assembly)`.
- [ ] New 3D types implemented via `IGLTFNodeConverter` in consuming project.
- [ ] Converters emit WORLD coordinates (no manual origin shift).
- [ ] Endpoint calls `ToSystem_Bytes(scene, batched: true)`.
- [ ] Response compression enabled for `model/gltf-binary`.
- [ ] `gltf-viewer-core.js` synced to `wwwroot/js/` — and committed in both repositories when changed.
- [ ] Nothing in the consumer reads the payload's vertex normals; the winding may be relied on, `shadowSide` pinned when `side` changes (§5).
- [ ] Explicit typing declared; no `var`; English only.
