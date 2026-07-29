# AI Guidelines: References (`IReference` / `IUniqueReference`)

## Mandatory Rule

> **NEVER compare two interface-typed references with `==` or `!=`. ALWAYS use `Core.Query.Equals(reference_1, reference_2)`.**

`==` between interface-typed operands compiles to **reference equality**, silently returning `false` for equal reference instances without compiler warnings.

---

## 1. Type Map & Casting Constraints

### Interfaces (`DiGi.Core/Interfaces/Reference/`)
`IObject` → `IReference` → `ISerializableReference` → `IInstanceRelatedSerializableReference` → `IUniqueReference` (adds `TypeReference`, `UniqueId`). Also: `ITypeRelatedSerializableReference`, `IComplexReference`, `IExternalReference`.

### Classes (`DiGi.Core/Classes/Reference/`)
`SerializableObject` → `SerializableReference` (defines `ToString()`, `Equals()`, `==`/`!=`)
- `UniqueReference` (`GuidReference`, `UniqueIdReference`)
- `TypeReference`, `ComplexReference`
- `ExternalReference` → `InstanceRelatedExternalReference<T>` → `UniqueExternalReference<T>` (implements `IUniqueReference`)

### Constraints
- **Do NOT cast `IReference` to `SerializableReference`.** Implementations may inherit directly from `SerializableObject` (e.g. `GISModelAreal2DReference`) or implement `IReference` directly (`ListClusterReference`).
- `IUniqueReference` has two separate class branches (`UniqueReference` and `UniqueExternalReference<T>`).

---

## 2. Equality Mechanics

- **Identity:** `ToString()` is sealed, caching the type discriminator + `Segments`. This rendered string defines identity.
- **Hash Code:** `GetHashCode()` is derived from the cached `ToString()` string.
- **Equality:** `Equals(IReference?)` returns `true` only when runtime types match AND cached strings match.
- **Collections:** `Dictionary<IUniqueReference, ...>`, `HashSet<IReference>`, `List.Contains`, `Find`, and `Remove` are safe because they route through `Equals`/`GetHashCode`.

---

## 3. Operator `==` Evaluation Matrix

| Operand Static Types | Compilation Target | Status |
|---|---|---|
| Both interfaces (`IReference`, `IUniqueReference`) | Predefined Reference Equality | **SILENT BUG** |
| At least one concrete `SerializableReference` | `SerializableReference.operator ==` → `Equals` | Correct |
| One side `null` literal | Null check | Correct |
| `.ToString()` on both sides | String comparison | Correct (allocates) |

### Why `==` Cannot Be Added to Interfaces
1. Interfaces contribute no operator candidates for `==` resolution.
2. Binary operators declared in external helpers require parameter declaring types (CS0563).
3. C# 11 static abstract interface operators require generic constraints and .NET 7+ (`DiGi.Core` targets `netstandard2.0`).

---

## 4. Clone-per-Call Accessor Trap

Model reference properties (e.g. `face.UniqueReference`) return `Core.Query.Clone(field)` (new instance per call).  
Therefore, `face.UniqueReference == face.UniqueReference` evaluates to `false`.

**Directives:**
- **Hoist to local variable:** Always assign property to a local variable before comparing.
- **Do not use returned instances as identity tokens.**

---

## 5. Replacement Guide

| Intent | Code Implementation |
|---|---|
| Compare two reference interfaces | `Core.Query.Equals(reference_1, reference_2)` (null-safe) |
| Concrete type access | Pattern-match: `if (uniqueReference is GuidReference guidReference)` |
| Model object instance identity | Compare object `Guid` (references identify target data, not container) |

---

## 6. Audit & Detection Recipe

### Ripgrep Commands
```bash
rg --pcre2 -n -g '*.cs' -i '\b[A-Za-z0-9_]*uniqueReference[A-Za-z0-9_]*\s*(==|!=)\s*(?!null)[A-Za-z_(]'
rg --pcre2 -n -g '*.cs' '\b[A-Za-z0-9_]*[Rr]eference[A-Za-z0-9_]*\s*(==|!=)\s*(?!null)[A-Za-z_(]'
```

### Triage Logic
A hit is a bug **ONLY IF both operands have interface declared types**.
- `x.UniqueReference == face.UniqueReference` → **BUG** (both `IUniqueReference?`).
- `x.UniqueReference_From == guidReference` → Valid (right operand concrete).
- `face.UniqueReference != null` → Valid (null check).

### Corrective Refactoring Template

```csharp
// INCORRECT — Silent reference equality bug
int index = faces.FindIndex(x => x.UniqueReference == face.UniqueReference);

// CORRECT — Hoist local variable, compare via Core.Query.Equals
IUniqueReference? uniqueReference = face.UniqueReference;
int index = faces.FindIndex(x => Core.Query.Equals(x?.UniqueReference, uniqueReference));
```
