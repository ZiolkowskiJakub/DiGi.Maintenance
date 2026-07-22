---
name: coding-references
description: Use when comparing, matching, keying or de-duplicating an IReference/IUniqueReference — why == between two interface-typed references is a silent bug, what to use instead, and how to detect and fix existing occurrences.
---

# AI Guidelines: References (`IReference` / `IUniqueReference`)

## When to read this
Read it before writing or reviewing code that **compares, matches, keys or de-duplicates** references —
`IReference`, `ISerializableReference`, `IUniqueReference`, `GuidReference`, `UniqueIdReference`,
`TypeReference`, and every `UniqueReference` property on a model object (`Face.UniqueReference`,
`Shell.UniqueReference`, `IOneToManyRelation.UniqueReference_From`, ...).

The headline rule, if you read nothing else:

> **Never compare two interface-typed references with `==` or `!=`. Use `Core.Query.Equals(reference_1, reference_2)`.**

This is not a style preference. `==` between two interface-typed operands compiles to *reference
equality*, silently returns `false` for two equal references, and the compiler emits no warning. It
has already produced an infinite loop in `BuildingModelShellUpdater` and mis-attributed geometry in
`ShellByPlaneSplitSolver`.

## 1. The type map
Interfaces (`DiGi.Core/Interfaces/Reference/`):

```
IObject
 └─ IReference : IEquatable<IReference>
     ├─ ISerializableReference : ISerializableObject, IReference
     │   ├─ IInstanceRelatedSerializableReference
     │   │   └─ IUniqueReference          (adds TypeReference, UniqueId)
     │   └─ ITypeRelatedSerializableReference
     ├─ IComplexReference
     └─ IExternalReference
```

Classes (`DiGi.Core/Classes/Reference/`):

```
SerializableObject
 └─ SerializableReference            ← owns ToString(), Equals(IReference?), GetHashCode() and the == / != operators
     ├─ UniqueReference               ├─ GuidReference
     │                                └─ UniqueIdReference
     ├─ TypeReference
     ├─ ComplexReference
     └─ ExternalReference
         └─ InstanceRelatedExternalReference<T>
             └─ UniqueExternalReference<T>    (also an IUniqueReference)
```

**Do not assume an `IReference` is a `SerializableReference` — never cast to it.** Counter-examples in
the workspace: `ListClusterReference<TKey_1, TKey_2>` implements `IReference` directly, and
`DiGi.GIS.Classes.GISModelAreal2DReference` implements `ISerializableReference` off plain
`SerializableObject`. Note also that `IUniqueReference` has **two** class branches — `UniqueReference`
and `UniqueExternalReference<T>` — with no common base below `SerializableReference`, so there is no
concrete type you can narrow a property to without excluding valid implementations.

## 2. What equality actually means
`SerializableReference` centralises the whole contract:

- `ToString()` is **sealed**. The base renders the type discriminator plus the derived type's
  `Segments`, and caches the result. That rendered string *is* the reference's identity.
- `GetHashCode()` is derived from that cached string.
- `Equals(IReference? reference)` returns true only when the runtime types match **and** the hash and
  the rendered string match.

Consequences worth internalising:

- Two independently constructed references to the same object **are** `Equals` and have the same hash,
  but are never `ReferenceEquals`.
- References of different runtime types are never equal, even if they render similarly.
- `Dictionary<IUniqueReference, ...>`, `HashSet<IReference>`, `List<T>.Contains`, `Find`, `FindAll`,
  `Remove` are all **safe** — they route through `Equals`/`GetHashCode`, never through the operators.

## 3. The `==` rule table
For `a == b`, C# gathers user-defined operator candidates from the **static types of the operands and
their base classes**. An interface contributes none.

| Static type of the operands | What `==` compiles to | Verdict |
|---|---|---|
| both interfaces (`IReference`, `IUniqueReference`, `ISerializableReference`, ...) | predefined reference equality | **silent bug** |
| at least one `SerializableReference`-derived (`GuidReference`, `TypeReference`, ...) | `SerializableReference.operator ==` → `Equals` | correct |
| one side is the `null` literal | null check | correct |
| `.ToString()` on both sides | string comparison | correct, but allocates |

`SerializableReference` deliberately declares four operator pairs, including
`==(SerializableReference?, object?)` and `==(object?, SerializableReference?)`. That is why a
comparison is fine as soon as **one** side is concrete:

```csharp
// CORRECT - right operand is GuidReference, so the operator applies (DiGi.GIS/Classes/GISModel.cs)
x => x?.UniqueReference_From is not null && x.UniqueReference_From == guidReference
```

## 4. Why this cannot be fixed by adding operators
Three independent blockers — do not re-open this:

1. **Interfaces contribute no operator candidates.** Nothing declared on `SerializableReference` (or
   anywhere else) can enter the candidate set when both operands are interface-typed.
2. **The operator cannot be declared elsewhere.** `public static bool operator ==(IReference, IReference)`
   in a helper class is **CS0563** — a binary operator's declaring type must be one of its parameter
   types — and interfaces cannot declare ordinary operators.
3. **C# 11 static abstract interface operators do not help.** They dispatch only *through a generic
   type parameter* constrained to the interface, so `IReference a, b; a == b` still uses reference
   equality; and they require net7.0+ while `DiGi.Core` targets **netstandard2.0**.

The only way to make `==` correct at a call site is to change the *static type* of an operand to a
concrete `SerializableReference`-derived type — which for a model property such as
`Face.UniqueReference` would exclude valid implementations. So: use `Equals`.

## 5. The compounding trap — clone-per-call accessors
Many model properties are implemented as `Core.Query.Clone(field)` and therefore hand back a **new
instance on every read**:

```csharp
public IUniqueReference? UniqueReference
{
    get { return Core.Query.Clone(uniqueReference); }
}
```

So `face.UniqueReference == face.UniqueReference` is `false` — the same face compared with itself.
Rules that follow:

- Read the property into a local before using it; do not call it inside a predicate that runs per
  element (it is also an allocation per iteration).
- Never rely on getting the same instance back, and never use the returned instance as an identity
  token. As a dictionary key it is fine — the dictionary uses `Equals`/`GetHashCode`.

## 6. What to use instead

| Intent | Use |
|---|---|
| Are these two references the same reference? | `Core.Query.Equals(reference_1, reference_2)` (null-safe, two nulls are equal) |
| Look up / group / de-duplicate | `Dictionary`, `HashSet`, `List.Find`/`FindAll`/`FindIndex`/`Contains` — already correct |
| I need the concrete API | pattern-match: `if (uniqueReference is GuidReference guidReference)` |
| Is this the same *instance* of a model object? | compare its `Guid` — a reference identifies the referenced object, not the object holding it. Several faces of one shell normally share one `UniqueReference` |

## 7. Detection recipe
Sweep with ripgrep (PCRE2 for the negative look-ahead):

```bash
rg --pcre2 -n -g '*.cs' -i '\b[A-Za-z0-9_]*uniqueReference[A-Za-z0-9_]*\s*(==|!=)\s*(?!null)[A-Za-z_(]'
```

```bash
rg --pcre2 -n -g '*.cs' '\b[A-Za-z0-9_]*[Rr]eference[A-Za-z0-9_]*\s*(==|!=)\s*(?!null)[A-Za-z_(]'
```

Then triage every hit — **most hits are sound.** A hit is a bug only if the *declared* type of **both**
operands is an interface. Resolve the declared type of each side before changing anything:

- `x?.Reference == reference` where `Reference` is `string?` → fine (most `DiGi.GIS` hits).
- `uniqueIdReference.TypeReference == new TypeReference(...)` → fine, both concrete.
- `x.UniqueReference_From == guidReference` → fine, right operand concrete.
- `face.UniqueReference != null` → fine, null check.
- `x?.UniqueReference_To?.ToString() == uniqueReference?.ToString()` → fine, string comparison.
- `x.UniqueReference == face.UniqueReference` → **bug**, both `IUniqueReference?`.

## 8. Fix template

```csharp
// WRONG - both operands are IUniqueReference, this is reference equality and never matches
int index = faces.FindIndex(x => x.UniqueReference == face.UniqueReference);
```

```csharp
// CORRECT - hoist the clone-returning accessor into a local, then compare by value
// References have to be compared by value, the equality operators are declared on SerializableReference and do not apply to IUniqueReference typed operands
IUniqueReference? uniqueReference = face.UniqueReference;

int index = faces.FindIndex(x => Core.Query.Equals(x?.UniqueReference, uniqueReference));
```

Worked references in the codebase:
`DiGi.Analytical/DiGi.Analytical/Classes/Solver/ShellByPlaneSplitSolver.cs` and
`DiGi.Analytical/DiGi.Analytical.Building/Classes/Updater/BuildingModelShellUpdater.cs`; the helper
lives in `DiGi.Core/DiGi.Core/Query/Equals.cs`; the trap itself is pinned by
`DiGi.Test/DiGi.Core.xUnit/Facts/Equals.cs` and
`DiGi.Test/DiGi.Analytical.xUnit/Facts/ShellByPlaneSplitSolver.cs`.

## Related
- [Coding - General.md](Coding%20-%20General.md) — naming/typing rules and the `Query`/`Modify`/`Create`/`Convert` architecture the helper belongs to.
- [Coding - API Documentation.md](Coding%20-%20API%20Documentation.md) — the generated API markdown carries the same warning in the `Remarks` of `IReference`, `IUniqueReference` and `SerializableReference`.
- [Coding - Automatic Tests.md](Coding%20-%20Automatic%20Tests.md) — how to add a fact covering a reference comparison.
