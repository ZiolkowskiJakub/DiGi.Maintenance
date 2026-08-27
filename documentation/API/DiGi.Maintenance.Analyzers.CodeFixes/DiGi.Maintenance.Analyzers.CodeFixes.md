## DiGi\.Maintenance\.Analyzers\.CodeFixes Namespace
### Classes

<a name='DiGi.Maintenance.Analyzers.CodeFixes.ParameterListLineBreakCodeFixProvider'></a>

## ParameterListLineBreakCodeFixProvider Class

CodeFixProvider for automatically reformatting parameter lists to satisfy the parameter line\-break rule\.

```csharp
public class ParameterListLineBreakCodeFixProvider
```

Inheritance [Microsoft\.CodeAnalysis\.CodeFixes\.CodeFixProvider](https://learn.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.codefixes.codefixprovider 'Microsoft\.CodeAnalysis\.CodeFixes\.CodeFixProvider') → ParameterListLineBreakCodeFixProvider
### Properties

<a name='DiGi.Maintenance.Analyzers.CodeFixes.ParameterListLineBreakCodeFixProvider.FixableDiagnosticIds'></a>

## ParameterListLineBreakCodeFixProvider\.FixableDiagnosticIds Property

Gets a list of diagnostic IDs that this provider can fix\.

```csharp
public override System.Collections.Immutable.ImmutableArray<string> FixableDiagnosticIds { get; }
```

#### Property Value
[System\.Collections\.Immutable\.ImmutableArray&lt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.immutable.immutablearray-1 'System\.Collections\.Immutable\.ImmutableArray\`1')[System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')[&gt;](https://learn.microsoft.com/en-us/dotnet/api/system.collections.immutable.immutablearray-1 'System\.Collections\.Immutable\.ImmutableArray\`1')
### Methods

<a name='DiGi.Maintenance.Analyzers.CodeFixes.ParameterListLineBreakCodeFixProvider.GetFixAllProvider()'></a>

## ParameterListLineBreakCodeFixProvider\.GetFixAllProvider\(\) Method

Gets an optional FixAllProvider that can fix all occurrences of the diagnostic\.

```csharp
public override FixAllProvider GetFixAllProvider();
```

#### Returns
[Microsoft\.CodeAnalysis\.CodeFixes\.FixAllProvider](https://learn.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.codefixes.fixallprovider 'Microsoft\.CodeAnalysis\.CodeFixes\.FixAllProvider')  
The batch fix all provider\.

<a name='DiGi.Maintenance.Analyzers.CodeFixes.ParameterListLineBreakCodeFixProvider.RegisterCodeFixesAsync(CodeFixContext)'></a>

## ParameterListLineBreakCodeFixProvider\.RegisterCodeFixesAsync\(CodeFixContext\) Method

Computes one or more fixes for the specified diagnostic context\.

```csharp
public override System.Threading.Tasks.Task RegisterCodeFixesAsync(CodeFixContext context);
```
#### Parameters

<a name='DiGi.Maintenance.Analyzers.CodeFixes.ParameterListLineBreakCodeFixProvider.RegisterCodeFixesAsync(CodeFixContext).context'></a>

`context` [Microsoft\.CodeAnalysis\.CodeFixes\.CodeFixContext](https://learn.microsoft.com/en-us/dotnet/api/microsoft.codeanalysis.codefixes.codefixcontext 'Microsoft\.CodeAnalysis\.CodeFixes\.CodeFixContext')

The code fix context containing diagnostic information\.

#### Returns
[System\.Threading\.Tasks\.Task](https://learn.microsoft.com/en-us/dotnet/api/system.threading.tasks.task 'System\.Threading\.Tasks\.Task')  
A task representing the asynchronous operation\.