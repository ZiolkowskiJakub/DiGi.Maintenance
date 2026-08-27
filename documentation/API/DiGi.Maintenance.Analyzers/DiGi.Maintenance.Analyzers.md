## DiGi\.Maintenance\.Analyzers Namespace
### Classes

<a name='DiGi.Maintenance.Analyzers.ParameterListLineBreakAnalyzer'></a>

## ParameterListLineBreakAnalyzer Class

Roslyn DiagnosticAnalyzer that enforces the parameter line\-break rule on method, constructor, and delegate parameter lists\.

Parameter lists with 1–7 parameters must remain on a single line regardless of length; parameter lists with 8 or more parameters must be split across multiple lines (one parameter per line).

```csharp
public class ParameterListLineBreakAnalyzer
```

Inheritance [Microsoft\.CodeAnalysis\.Diagnostics\.DiagnosticAnalyzer](https://learn.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.diagnostics.diagnosticanalyzer 'Microsoft\.CodeAnalysis\.Diagnostics\.DiagnosticAnalyzer') → ParameterListLineBreakAnalyzer
### Fields

<a name='DiGi.Maintenance.Analyzers.ParameterListLineBreakAnalyzer.DiagnosticId'></a>

## ParameterListLineBreakAnalyzer\.DiagnosticId Field

Diagnostic ID for parameter line\-break rule violations\.

```csharp
public const string DiagnosticId = "DIGI0001";
```

#### Field Value
[System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')
### Properties

<a name='DiGi.Maintenance.Analyzers.ParameterListLineBreakAnalyzer.SupportedDiagnostics'></a>

## ParameterListLineBreakAnalyzer\.SupportedDiagnostics Property

Gets the set of descriptors for diagnostics supported by this analyzer\.

```csharp
public override System.Collections.Immutable.ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics { get; }
```

#### Property Value
[System\.Collections\.Immutable\.ImmutableArray&lt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.immutable.immutablearray-1 'System\.Collections\.Immutable\.ImmutableArray\`1')[Microsoft\.CodeAnalysis\.DiagnosticDescriptor](https://learn.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.diagnosticdescriptor 'Microsoft\.CodeAnalysis\.DiagnosticDescriptor')[&gt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.immutable.immutablearray-1 'System\.Collections\.Immutable\.ImmutableArray\`1')
### Methods

<a name='DiGi.Maintenance.Analyzers.ParameterListLineBreakAnalyzer.Initialize(AnalysisContext)'></a>

## ParameterListLineBreakAnalyzer\.Initialize\(AnalysisContext\) Method

Initializes the analyzer by registering actions for syntax node analysis\.

```csharp
public override void Initialize(AnalysisContext context);
```
#### Parameters

<a name='DiGi.Maintenance.Analyzers.ParameterListLineBreakAnalyzer.Initialize(AnalysisContext).context'></a>

`context` [Microsoft\.CodeAnalysis\.Diagnostics\.AnalysisContext](https://learn.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.diagnostics.analysiscontext 'Microsoft\.CodeAnalysis\.Diagnostics\.AnalysisContext')

The analysis context to register actions with\.