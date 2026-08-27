---
name: coding-editor-config
description: Use when configuring, auditing, or enforcing .editorconfig code styles, explicit typing (no var), block-scoped namespaces, collection expressions, target-typed new(), and Visual Studio 2026 / C# 13/14 formatting rules across DiGi repositories.
---

# AI Guidelines: C# EditorConfig & Code Formatting Standards

**Environment:** Visual Studio 2026 / Windows 11 / .NET 9.0–10.0 / C# 13–14+.  
**Purpose:** Definitive `.editorconfig` baseline, code style rules, and AI generation standards across all DiGi repositories.

---

## 1. Summary of Base Codebase Standards

- **Explicit Typing (No `var`):** Enforced across all projects (`csharp_style_var_* = false:warning`).
- **Block-Scoped Namespaces:** Enforced (`csharp_style_namespace_declarations = block_scoped:warning`). Prohibit file-scoped namespaces.
- **Collection Expressions & `new()`:** Enforced `[]` (`csharp_style_prefer_collection_expression = true:warning`) and target-typed `new()` (`csharp_style_implicit_object_creation_when_type_is_apparent = true:warning`).
- **Member Body Discipline:**
  - **Block-Bodied (`false:silent`):** Methods, constructors, operators, local functions.
  - **Expression-Bodied (`true:silent`):** Single-line properties, indexers, accessors (get/set), lambdas.
- **Modern Features:** C# 13 `System.Threading.Lock` (`csharp_prefer_system_threading_lock = true:suggestion`), range operators (`1..3`), UTF-8 literals (`"text"u8`).
- **Diagnostic Overrides:** `IDE0130 = none` (logical namespaces), `CA1707 = none` (underscores in conversion methods `To[TargetArea]_[TargetType]`), `CS1591 = none`, `IDE0290 = none`.

---

## 2. Standardized Baseline `.editorconfig`

```ini
root = true

[*]
end_of_line = crlf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
indent_style = space
indent_size = 4
tab_width = 4

[*.cs]
# Compiler Diagnostic Severity Overrides
dotnet_diagnostic.IDE0130.severity = none
dotnet_diagnostic.IDE0290.severity = none
dotnet_diagnostic.CS1591.severity = none
dotnet_diagnostic.IDE1006.severity = none
dotnet_diagnostic.CA1016.severity = none
dotnet_diagnostic.CA1707.severity = none
dotnet_diagnostic.CA1711.severity = none

# Indentation and layout rules
csharp_indent_labels = one_less_than_current
csharp_using_directive_placement = outside_namespace:silent
csharp_prefer_simple_using_statement = true:suggestion
csharp_prefer_braces = true:silent

# General C# style settings conforming to DiGi AI Guidelines
# 1. Enforce block-scoped namespaces
csharp_style_namespace_declarations = block_scoped:warning

# 2. Enforce explicit typing (no 'var' rule)
csharp_style_var_else = false:warning
csharp_style_var_for_built_in_types = false:warning
csharp_style_var_when_type_is_apparent = false:warning

# 3. Enforce collection expressions []
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
csharp_style_prefer_primary_constructors = true:none
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

dotnet_naming_rule.interface_should_be_begins_with_i.severity = suggestion
dotnet_naming_rule.interface_should_be_begins_with_i.symbols = interface
dotnet_naming_rule.interface_should_be_begins_with_i.style = begins_with_i

dotnet_naming_rule.types_should_be_pascal_case.severity = suggestion
dotnet_naming_rule.types_should_be_pascal_case.symbols = types
dotnet_naming_rule.types_should_be_pascal_case.style = pascal_case

dotnet_naming_rule.non_field_members_should_be_pascal_case.severity = suggestion
dotnet_naming_rule.non_field_members_should_be_pascal_case.symbols = non_field_members
dotnet_naming_rule.non_field_members_should_be_pascal_case.style = pascal_case

dotnet_naming_symbols.interface.applicable_kinds = interface
dotnet_naming_symbols.interface.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.interface.required_modifiers = 

dotnet_naming_symbols.types.applicable_kinds = class, struct, interface, enum
dotnet_naming_symbols.types.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.types.required_modifiers = 

dotnet_naming_symbols.non_field_members.applicable_kinds = property, event, method
dotnet_naming_symbols.non_field_members.applicable_accessibilities = public, internal, private, protected, protected_internal, private_protected
dotnet_naming_symbols.non_field_members.required_modifiers = 

dotnet_naming_style.begins_with_i.required_prefix = I
dotnet_naming_style.begins_with_i.required_suffix = 
dotnet_naming_style.begins_with_i.word_separator = 
dotnet_naming_style.begins_with_i.capitalization = pascal_case

dotnet_naming_style.pascal_case.required_prefix = 
dotnet_naming_style.pascal_case.required_suffix = 
dotnet_naming_style.pascal_case.word_separator = 
dotnet_naming_style.pascal_case.capitalization = pascal_case

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
dotnet_style_namespace_match_folder = false:none

dotnet_diagnostic.IDE0130.severity = none
dotnet_diagnostic.IDE0290.severity = none
dotnet_diagnostic.CS1591.severity = none
dotnet_diagnostic.IDE1006.severity = none
dotnet_diagnostic.CA1016.severity = none
dotnet_diagnostic.CA1707.severity = none
dotnet_diagnostic.CA1711.severity = none
```

---

## 3. Code Generation Rules & Checklist

1. **Explicit Typing (No `var`):** Declare explicit types; pair with target-typed `new()`.
   ```csharp
   // CORRECT
   PointNode pointNode = new();
   List<double> coordinates = [];

   // INCORRECT
   var pointNode = new PointNode();
   ```
2. **Collection Expressions:** Use `[]` for arrays and collections (`List<int> numbers = [];`).
3. **Block-Scoped Namespaces:** Always use `namespace DiGi.Domain { ... }`.
4. **Parameter Line Breaks (`<= 7` Rule):** Keep parameter declarations on a single line if count <= 7, however long the line becomes; multi-line only for >= 8 parameters (strictly one parameter per line, enforced via `DIGI0001`). Line length is never the trigger. Call sites prefer single-line but allow multi-line formatting for complex expressions, lambdas, or readability.
5. **Member Body Rules:** Full block bodies `{ ... }` for methods, constructors, operators, local functions; `=>` for single-line properties/getters.
6. **Async & Token Placement:** Async method names end with `Async`. `CancellationToken` must be the LAST parameter (CA1068). Pass by name at call sites (`cancellationToken: cancellationToken`).
7. **C# 13 Thread Synchronization:** Use `private readonly Lock lockObject = new();` and `lock (lockObject)`.

### Verification Checklist
- [ ] Block-scoped namespace used?
- [ ] Explicit typing declared (no `var`)?
- [ ] Target-typed `new()` and collection `[]` applied?
- [ ] Method bodies use `{ ... }`?
- [ ] Parameter declarations single-line if count <= 7 (or strictly one per line if >= 8)?
- [ ] `CancellationToken` is final parameter in async methods?
- [ ] Async methods end with `Async`?
