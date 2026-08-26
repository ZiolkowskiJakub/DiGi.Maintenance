# Coding — WebAPI Contracts (Controllers and Their HTTP Clients)

Rules for the wire contract between a `DiGi.*.WebAPI` controller and the code that calls it over HTTP.
Read this when changing a controller's route, parameter names or validation, and when writing or
maintaining a client (`DiGi.GIS.WebAPI.UI`, `DiGi.GIS.UI`, a background task, a page script).

For *testing* against the live host see [Coding - Deployed WebAPI.md](Coding%20-%20Deployed%20WebAPI.md).
For the `DiGi.GLTF` 3D pipeline see [Coding - WebAPI GLTF.md](Coding%20-%20WebAPI%20GLTF.md).

---

## 1. The contract has no compiler — a renamed parameter breaks clients in silence

> **A client reaches a `*.WebAPI` over HTTP only.** `DiGi.GIS.WebAPI.UI` has no `HintPath` and no
> project reference to `DiGi.GIS.WebAPI`. Renaming a `[FromQuery(Name = "…")]` produces **no compile
> error in the client, and no runtime error either** — ASP.NET Core silently ignores a query parameter
> it does not recognise and answers with the *unfiltered* result.

Real incident. `DiGi.GIS.WebAPI` renamed `itemsbypoint`'s filter from `type` to
`administrativearealtype`. `DiGi.GIS.WebAPI.UI/Controllers/Building2DController.cs` kept sending
`type=County` and nothing anywhere reported a problem. Measured against the deployed host:

| Request | Bytes | First item returned |
|---|---|---|
| `itemsbypoint?x=638000&y=486000&type=County` | 2 119 202 | `Polska`, code `10` — **the country** |
| `itemsbypoint?x=638000&y=486000&administrativearealtype=2` | 387 089 | `m. St. Warszawa`, code `1465` |

The client read `FirstOrDefault()`, got the country, resolved no county, and dropped `countyid` from
every downstream request — a wrong answer plus a 5x payload, for months, with a clean build.

**After changing any route or parameter name, diff the two sides by hand.** Nothing else catches it.
Declared names on the API side:

```bash
grep -rnoE '\[FromQuery\(Name = "[^"]+"\)\]' --include=*.cs DiGi.GIS.WebAPI/Classes/Controller/ | sort -u
```

Sent names across **every** consumer — the GIS Web API has more than one, which is easy to forget:

```bash
grep -rnoE 'AddParameter\("[^"]+"|api\.digiproject\.uk[^"]*' --include=*.cs DiGi.GIS.WebAPI.UI DiGi.GIS.UI DiGi.GIS.IO | sort -u
```

| Consumer | Where |
|---|---|
| `DiGi.GIS.WebAPI.UI` | every file under `Controllers/`, `Query/`, `Create/` |
| `DiGi.GIS.UI` (desktop) | `DiGi.GIS.UI.Application/Windows/MainWindow.xaml.cs`, `DiGi.GIS.UI/Modify/TryDownload.cs` |
| `DiGi.GIS.IO` | `Modify/Update.cs` (builds an `ortodatas/imagebyreference` URL into a spreadsheet cell) |

Also sweep the front end, which builds its own query strings:
`grep -rnE "fetch\(|\?[a-z]+=" --include=*.js --include=*.cshtml`.

Renaming a parameter is a **breaking wire change**. Prefer adding the new name and accepting both for
one release; when that is not worth it, treat the rename as a deployment step with a client change
landing alongside it.

---

## 2. Binding traps that fail silently

### An omitted parameter is not a binding failure

`[ApiController]` returns an automatic **400** when a value is present but unparseable — verified
against the deployed host: `administrativearealtype=` → 400, `administrativearealtype=Nonsense` → 400.
It does **not** fire when the parameter is **absent**. An absent simple-type parameter simply keeps
`default(T)`: `0` for `int`, `0.0` for `double`, `false` for `bool`, `(T)0` for an enum.

> **If "absent" must be distinguishable from a legitimate value, bind the parameter as nullable and
> reject `null` explicitly.** A non-nullable `double x` cannot tell an omitted coordinate from the
> valid coordinate `0`.

### An enum sentinel that is not `0` makes the obvious guard dead code

`DiGi.GIS.PostgreSQL.Enums.AdministrativeArealType` is `Undefined = -1`, `Country = 0`,
`Voivodeship = 1`, `County = 2`, `Municipality = 3`, `Subdivision = 4`. So for a non-nullable binding:

```csharp
// WRONG - never fires for an omitted parameter, which binds to Country (0), not Undefined (-1).
public async Task<IActionResult> GetAsync([FromQuery(Name = "administrativearealtype")] AdministrativeArealType administrativeArealType, CancellationToken cancellationToken = default)
{
    if (administrativeArealType == AdministrativeArealType.Undefined)
    {
        return BadRequest();
    }
```

Verified against the deployed host: omitting `administrativearealtype` on
`administrativeareal2Dreferencesbyadministrativearealtype` returns a payload **byte-identical** to
passing `administrativearealtype=0`, headed by `Polska`. The caller asked nothing and silently got
countries.

```csharp
// RIGHT - absence is representable, so it can be rejected.
public async Task<IActionResult> GetAsync([FromQuery(Name = "administrativearealtype")] AdministrativeArealType? administrativeArealType, CancellationToken cancellationToken = default)
{
    if (administrativeArealType is null || administrativeArealType.Value == AdministrativeArealType.Undefined)
    {
        return BadRequest();
    }
```

Keep a nullable binding where the parameter genuinely **is** optional, and let `null` mean "no filter" —
just do not also compare it to the sentinel and imagine that covers the omitted case.

### Send enum values as integers

A client must put the **integer** on the wire, not the member name:
`urlBuilder.AddParameter("administrativearealtype", (int)AdministrativeArealType.County)`. The member
name binds only against a build whose enum spelling matches, and DiGi has already shipped one rename
(`Subdivison` → `Subdivision`) that makes the name a moving target while the integer never moved.
Against the deployed host: `administrativearealtype=Subdivision` and `administrativearealtype=4`
return byte-identical payloads, while the pre-rename `administrativearealtype=Subdivison` is a hard
**400**.

`…ToString()` on the enum is therefore a latent 400 waiting for the next rename — it is what
`DiGi.GIS.UI.Application/Windows/MainWindow.xaml.cs` does today (`AdministrativeArealType.Subdivision.ToString()`),
which works only because that client and the deployed build happen to agree on the spelling right now.
Cast to `int` instead. See [Coding - Deployed WebAPI.md](Coding%20-%20Deployed%20WebAPI.md) §4 and
[Coding - GIS Administrative Data.md](Coding%20-%20GIS%20Administrative%20Data.md) §6.

---

## 3. Client / proxy structure

A UI that fronts a WebAPI is still a DiGi project: the
[Coding - General.md](Coding%20-%20General.md) architecture applies unchanged. Reference shape:
`DiGi.GIS.WebAPI.UI`.

- **One base URI constant, never a literal.** `Constants.Default.GISWebAPIUri` (plus a
  `…Uri_Development` sibling), with every other URL composed from it —
  `public const string TerrainUri = GISWebAPIUri + "/gis/terrain";`. A literal repeated per call site
  cannot be repointed at another host.
- **HTTP plumbing belongs in `/Query`, not in the controller.** `CreateClient` → `GetAsync` →
  `IsSuccessStatusCode` → `ReadAsStringAsync` → `Core.Convert.ToDiGi<T>` is five lines that must not be
  copied into every action. One public member per file, extension methods on `HttpClient?`:

  | Member | Returns |
  |---|---|
  | `JsonAsync(requestUri, cancellationToken)` | raw body, for verbatim relay |
  | `ItemsAsync<T>(requestUri, cancellationToken)` | `List<T>?` via `Core.Convert.ToDiGi<T>` |
  | `ItemAsync<T>(requestUri, cancellationToken)` | the first item |
  | `PostJsonAsync<T>(requestUri, value, cancellationToken)` | raw body, for body-criteria endpoints |

  `T` is constrained to `Core.Interfaces.ISerializableObject`. The HTTP verb stays in `PostJsonAsync`'s
  name — the verb is the only thing distinguishing it from its sibling — matching the existing
  `DiGi.WebAPI.Query.GetAsync` precedent, and this is the recognised exception to the
  no-verb-prefix rule for `Query`.
- **Collapse every failure to `null` and let the caller decide.** A page is assembled from several
  independent requests; one of them failing must leave the rest of the page standing. The controller
  then maps `null` to `NoContent()`, which the front end already treats as "hide this panel". Do not
  map an upstream 500 to `BadRequest()` — it blames the caller for a server fault and turns a hidden
  panel into a console error.
- **Do not reuse `DiGi.WebAPI.Query.GetAsync<T>` for this.** It throws on any non-2xx status and takes
  no `CancellationToken` (it derives one from `PostOptions.Delay`), so it fits a background task, not a
  page that must degrade.
- **`CancellationToken` on every action that issues an outbound request**, last parameter (CA1068),
  threaded all the way through. Without it a browser that navigates away leaves the outbound request
  running to completion.

---

## 4. Do not build on an endpoint that is not deployed yet

The deployed host lags the repository, so an endpoint that exists in source may still answer **404**.
Check what is actually running before writing a client against it:

```bash
# Check deployed controller builds and commit hashes
curl -s "https://api.digiproject.uk/information/controllers"

# Check exact active routes and parameter names (including unlisted endpoints)
curl -s "https://api.digiproject.uk/information/endpoints?includeignored=true"
```

`InformationalVersion` carries the commit hash. Compare it with `git log` for the controller you need.
Querying `/information/endpoints` confirms whether the specific action route, HTTP verb, and query parameter names match what your client expects.

When a client must ship before the endpoint does, gate the call and mark it with a grep-able
`TODO [MarkerName]` per the temporary-code rule in
[Coding - General.md](Coding%20-%20General.md) §1, stating the **observable** removal condition —
"once `GET /information/controllers` reports a build carrying `idsbycode`" — not merely that the code
is temporary.

---

## 5. Checklist

**Changing a controller**
- [ ] Renamed or removed a `[FromQuery(Name = "…")]`? Grep every client and the front-end query strings.
- [ ] Non-nullable parameter whose absence matters? Make it nullable and reject `null`.
- [ ] Enum guard compared against a sentinel that is not `0`? It does not cover the omitted case.
- [ ] `CancellationToken` last, and actually passed to the converter/query beneath.

**Writing a client**
- [ ] Base URI from a constant; no literal host anywhere else.
- [ ] Request/deserialize through the `/Query` helpers, not inline in the action.
- [ ] Enum values sent as integers.
- [ ] Absence degrades (`NoContent`), it does not fail the page.
- [ ] Every endpoint used is present on the deployed host, or gated behind a `TODO [MarkerName]`.
