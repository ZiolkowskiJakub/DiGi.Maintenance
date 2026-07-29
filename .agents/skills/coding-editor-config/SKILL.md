---
name: coding-editor-config
description: Use when configuring, auditing, or enforcing .editorconfig code styles, explicit typing (no var), block-scoped namespaces, collection expressions, target-typed new(), and Visual Studio 2026 / C# 13/14 formatting rules across DiGi repositories.
---

# AI Guidelines: C# EditorConfig & Code Formatting Standards

## Role & Context
- **Environment:** Visual Studio 2026 on Windows 11.
- **Target Frameworks:** .NET 9.0 / .NET 10.0, C# 13 / C# 14+.
- **Domain:** Engineering & Architectural software development (Revit API, RhinoCommon, Grasshopper, WebAPI, GIS, Analytical Engines).
- **Purpose:** Definitive reference for `.editorconfig` formatting, style enforcement, naming conventions, and AI code generation rules across all DiGi repositories.

---

## 1. Executive Summary of DiGi Codebase Patterns

An automated scan of **62 `.editorconfig` files** across all DiGi project repositories in `C:\Users\jakub\GitHub\` revealed 19 distinct configuration groups. Analysis of these configurations shows a clear evolution toward modernized C# standards while maintaining strict domain-specific conventions.

### Key Analysis & Findings

1. **Strict Explicit Typing Policy (No `var`)**
   - DiGi enforces explicit variable typing across all codebase branches.
   - Analyzer rules (`csharp_style_var_else`, `csharp_style_var_for_built_in_types`, `csharp_style_var_when_type_is_apparent`) are set to `false:warning`.
   - Explicit types are mandatory except where forced by the compiler (e.g., anonymous types).

2. **Block-Scoped Namespaces**
   - Standard across all projects: `csharp_style_namespace_declarations = block_scoped:warning`.
   - File-scoped namespaces are explicitly prohibited in DiGi architecture to maintain uniform nesting and scoping structure.

3. **Collection Expressions & Target-Typed Instantiation**
   - C# 12+ collection expressions (`[1, 2, 3]` and `[]`) are enforced with `csharp_style_prefer_collection_expression = true:warning`.
   - Target-typed `new()` syntax (`PointNode node = new();`) is enforced with `csharp_style_implicit_object_creation_when_type_is_apparent = true:warning`.

4. **Expression-Bodied vs Block-Bodied Member Strategy**
   - **Block-Bodied** (`false:silent`): Methods, constructors, operators, and local functions must use full block bodies `{ ... }` to improve debuggability and multi-line extensibility.
   - **Expression-Bodied** (`true:silent`): Single-line properties, indexers, accessors (get/set), and lambdas prefer `=>` syntax.

5. **Modern C# 13/14 & VS 2026 Features**
   - System Threading Lock: `csharp_prefer_system_threading_lock = true:suggestion` (preferring C# 13 `System.Threading.Lock` over `object`).
   - Primary Constructors: `csharp_style_prefer_primary_constructors = true:suggestion`.
   - Modern Index/Range: `csharp_style_prefer_index_operator = true:suggestion` (`^1`), `csharp_style_prefer_range_operator = true:suggestion` (`1..3`).
   - UTF-8 String Literals: `csharp_style_prefer_utf8_string_literals = true:suggestion` (`"text"u8`).

6. **Domain-Specific Diagnostic Overrides**
   - `IDE0130 = none`: Disables namespace location diagnostics, allowing DiGi's logical namespace hierarchy (`DiGi.[Domain].Classes`, `Query`, `Modify`, `Convert`) regardless of physical folder structures.
   - `CA1707 = none`: Allows underscores in method identifiers, specifically supporting `To[TargetArea]_[TargetType]` conversion naming (e.g., `ToDiGi_Table`, `ToSystem_String`).
   - `IDE0290 = none` / `CS1591 = none`: Suppresses non-essential warnings for primary constructors and public XML doc requirements where internal architectural contracts govern.

---

## 2. Standardized DiGi Baseline `.editorconfig`

Below is the unified, definitive `.editorconfig` baseline file to be used across all present and future DiGi project repositories.

```ini
root = true

# Compiler Diagnostic Severity Overrides
dotnet_diagnostic.IDE0130.severity = none
dotnet_diagnostic.IDE0290.severity = none
dotnet_diagnostic.CS1591.severity = none
dotnet_diagnostic.IDE1006.severity = none
dotnet_diagnostic.CA1016.severity = none
dotnet_diagnostic.CA1707.severity = none
dotnet_diagnostic.CA1711.severity = none

# Global settings for all files in the project
[*]
end_of_line = crlf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
indent_style = space
indent_size = 4
tab_width = 4

[*.cs]
# Indentation and layout rules
csharp_indent_labels = one_less_than_current
csharp_using_directive_placement = outside_namespace:silent
csharp_prefer_simple_using_statement = true:suggestion
csharp_prefer_braces = true:silent

# General C# style settings conforming to DiGi AI Guidelines
# 1. Enforce block-scoped namespaces (DiGi convention)
csharp_style_namespace_declarations = block_scoped:warning

# 2. Enforce explicit typing (no 'var' rule)
csharp_style_var_else = false:warning
csharp_style_var_for_built_in_types = false:warning
csharp_style_var_when_type_is_apparent = false:warning

# 3. Enforce collection expressions [] instead of new List<T>() or new T[] {}
csharp_style_prefer_collection_expression = true:warning

# 4. Enforce target-typed new()
csharp_style_implicit_object_creation_when_type_is_apparent = true:warning

# Expression-bodied members discipline
csharp_style_expression_bodied_methods = false:silent
csharp_style_expression_bodied_constructors = false:silent
csharp_style_expression_bodied_operators = false:silent
csharp_style_expression_bodied_local_functions = false:silent
csharp_style_expression_bodied_properties = true:silent
csharp_style_expression_bodied_indexers = true:silent
csharp_style_expression_bodied_accessors = true:silent
csharp_style_expression_bodied_lambdas = true:silent

# Modern C# features and standard suggestions
csharp_style_prefer_method_group_conversion = true:silent
csharp_style_prefer_top_level_statements = true:silent
csharp_style_prefer_primary_constructors = true:suggestion
csharp_prefer_system_threading_lock = true:suggestion
csharp_space_around_binary_operators = before_and_after
csharp_style_throw_expression = true:suggestion
csharp_style_prefer_null_check_over_type_check = true:suggestion
csharp_prefer_simple_default_expression = true:suggestion
csharp_style_prefer_local_over_anonymous_function = true:suggestion
csharp_style_prefer_index_operator = true:suggestion
csharp_style_prefer_range_operator = true:suggestion
csharp_style_prefer_implicitly_typed_lambda_expression = true:suggestion
csharp_style_prefer_tuple_swap = true:suggestion
csharp_style_prefer_unbound_generic_type_in_nameof = true:suggestion
csharp_style_prefer_utf8_string_literals = true:suggestion
csharp_style_inlined_variable_declaration = true:suggestion
csharp_style_deconstructed_variable_declaration = true:suggestion
csharp_style_unused_value_assignment_preference = discard_variable:suggestion

[*.{cs,vb}]
#### Naming styles ####

# Naming rules
dotnet_naming_rule.interface_should_be_begins_with_i.severity = suggestion
dotnet_naming_rule.interface_should_be_begins_with_i.symbols = interface
dotnet_naming_rule.interface_should_be_begins_with_i.style = begins_with_i

dotnet_naming_rule.types_should_be_pascal_case.severity = suggestion
dotnet_naming_rule.types_should_be_pascal_case.symbols = types
dotnet_naming_rule.types_should_be_pascal_case.style = pascal_case

dotnet_naming_rule.non_field_members_should_be_pascal_case.severity = suggestion
dotnet_naming_rule.non_field_members_should_be_pascal_case.symbols = non_field_members
dotnet_naming_rule.non_field_members_should_be_pascal_case.style = pascal_case

# Symbol specifications
dotnet_naming_symbols.interface.applicable_kinds = interface
dotnet_naming_symbols.interface.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.interface.required_modifiers = 

dotnet_naming_symbols.types.applicable_kinds = class, struct, interface, enum
dotnet_naming_symbols.types.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.types.required_modifiers = 

dotnet_naming_symbols.non_field_members.applicable_kinds = property, event, method
dotnet_naming_symbols.non_field_members.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.non_field_members.required_modifiers = 

# Naming styles
dotnet_naming_style.begins_with_i.required_prefix = I
dotnet_naming_style.begins_with_i.required_suffix = 
dotnet_naming_style.begins_with_i.word_separator = 
dotnet_naming_style.begins_with_i.capitalization = pascal_case

dotnet_naming_style.pascal_case.required_prefix = 
dotnet_naming_style.pascal_case.required_suffix = 
dotnet_naming_style.pascal_case.word_separator = 
dotnet_naming_style.pascal_case.capitalization = pascal_case

# Operator wrapping and standard settings
dotnet_style_operator_placement_when_wrapping = beginning_of_line
dotnet_style_coalesce_expression = true:suggestion
dotnet_style_null_propagation = true:suggestion
dotnet_style_prefer_is_null_check_over_reference_equality_method = true:suggestion
dotnet_style_prefer_auto_properties = true:silent
dotnet_style_object_initializer = true:suggestion
dotnet_style_collection_initializer = true:suggestion
dotnet_style_prefer_simplified_boolean_expressions = true:suggestion
dotnet_style_prefer_conditional_expression_over_assignment = true:silent
dotnet_style_prefer_conditional_expression_over_return = true:silent
dotnet_style_explicit_tuple_names = true:suggestion
dotnet_style_prefer_inferred_tuple_names = true:suggestion
dotnet_style_prefer_inferred_anonymous_type_member_names = true:suggestion
dotnet_style_prefer_compound_assignment = true:suggestion
dotnet_style_prefer_simplified_interpolation = true:suggestion
dotnet_style_namespace_match_folder = true:suggestion
```

---

## 3. Guidelines for AI Code Generation & Rule Enforcement

When generating, modifying, or refactoring C# code in any DiGi repository, AI agents **must strictly adhere** to the following code formatting and syntax rules.

### Rule 1: Explicit Variable Typing (Strictly NO `var`)
- **Mandatory:** Always declare explicit types for local variables.
- **Allowed Exception:** Only when compiler requires it (e.g., anonymous types).
- **Target-Typed `new()`:** Pair explicit type declarations with target-typed constructor calls (`new()`).

```csharp
// CORRECT
PointNode pointNode = new();
List<double> coordinates = [];
double tolerance = 0.001;

// INCORRECT - DO NOT USE
var pointNode = new PointNode();
var coordinates = new List<double>();
var suddenVar = 0.001;
```

### Rule 2: Collection Expressions (`[]`)
- **Mandatory:** Use C# 12+ collection expressions for arrays, lists, and collections.

```csharp
// CORRECT
List<int> numbers = [];
string[] labels = ["Alpha", "Beta", "Gamma"];

// INCORRECT
List<int> numbers = new List<int>();
string[] labels = new string[] { "Alpha", "Beta", "Gamma" };
```

### Rule 3: Block-Scoped Namespaces
- **Mandatory:** Always enclose code inside traditional block-scoped namespaces `{ ... }`.
- **Prohibited:** File-scoped namespaces (`namespace DiGi.Core;`).

```csharp
// CORRECT
namespace DiGi.Geometry.Classes
{
    public class PointNode
    {
    }
}

// INCORRECT
namespace DiGi.Geometry.Classes;

public class PointNode
{
}
```

### Rule 4: Parameter Line Breaks & Formatting (<= 5 Rule)
- **Mandatory:** If a method or constructor has **5 or fewer** input parameters, keep all parameters on a **single line**.
- **Line Breaks:** Only split parameters into multiple lines if there are **6 or more** parameters.

```csharp
// CORRECT (4 parameters - single line)
public void CalculateBounds(double centerX, double centerY, double radius, double? height = null)
{
}

// INCORRECT (Do NOT break lines for < 6 parameters)
public void CalculateBounds(
    double centerX,
    double centerY,
    double radius,
    double? height = null)
{
}
```

### Rule 5: Member Expression-Body Rules
- **Methods, Constructors, Operators, Local Functions:** Must use block bodies `{ ... }`.
- **Properties & Getters/Setters:** Use expression body `=>` for single-line getters/properties.

```csharp
// CORRECT
public class DistanceCalculator
{
    public double DefaultTolerance => 1e-6;

    public double ComputeDistance(PointNode pointNode_A, PointNode pointNode_B)
    {
        return Math.Sqrt(Math.Pow(pointNode_A.X - pointNode_B.X, 2) + Math.Pow(pointNode_A.Y - pointNode_B.Y, 2));
    }
}

// INCORRECT (Methods should not be expression-bodied)
public double ComputeDistance(PointNode pointNode_A, PointNode pointNode_B) =>
    Math.Sqrt(Math.Pow(pointNode_A.X - pointNode_B.X, 2) + Math.Pow(pointNode_A.Y - pointNode_B.Y, 2));
```

### Rule 6: Asynchronous Methods & Cancellation Tokens
- **Method Naming:** Async methods must end with `Async` suffix.
- **Token Placement:** `CancellationToken` must always be the **LAST** parameter in the signature.
- **Named Arguments at Call Sites:** Always pass tokens using named parameters (`cancellationToken: cancellationToken`).

```csharp
// CORRECT
public static async Task<bool> ProcessDataAsync(NpgsqlConnection npgsqlConnection, string tableName, CancellationToken cancellationToken = default)
{
    return await ExecuteCommandAsync(npgsqlConnection, tableName, cancellationToken: cancellationToken);
}

// INCORRECT (Token is not last)
public static async Task<bool> ProcessDataAsync(NpgsqlConnection npgsqlConnection, CancellationToken cancellationToken = default, string tableName = "Default")
```

### Rule 7: C# 13 `System.Threading.Lock`
- **Mandatory:** Use `System.Threading.Lock` object instead of `object` for synchronizing threads.

```csharp
// CORRECT (C# 13)
private readonly Lock lockObject = new();

public void ModifyData()
{
    lock (lockObject)
    {
        // Thread-safe code
    }
}
```

### Summary Checklist for AI Agents
When generating code for DiGi:
1. [ ] Is namespace block-scoped?
2. [ ] Are all local variables explicitly typed (no `var`)?
3. [ ] Are object instantiations target-typed (`new()`)?
4. [ ] Are collection initializations using `[]` syntax?
5. [ ] Are methods using block bodies `{ ... }`?
6. [ ] Are method parameters on a single line if count <= 5?
7. [ ] Is `CancellationToken` the final parameter in async methods?
8. [ ] Do async method names end in `Async`?
