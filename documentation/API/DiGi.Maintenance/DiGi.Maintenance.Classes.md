#### [DiGi\.Maintenance](index.md 'index')

## DiGi\.Maintenance\.Classes Namespace
### Classes

<a name='DiGi.Maintenance.Classes.MaintenanceConfigurationFile'></a>

## MaintenanceConfigurationFile Class

Represents the configuration settings specifically for maintenance operations, extending the base configuration file functionality\.

```csharp
public class MaintenanceConfigurationFile : DiGi.Core.Classes.ConfigurationFile
```

Inheritance [System\.Object](https://learn.microsoft.com/en-us/dotnet/api/system.object 'System\.Object') → [DiGi\.Core\.Classes\.Object](https://learn.microsoft.com/en-us/dotnet/api/digi.core.classes.object 'DiGi\.Core\.Classes\.Object') → [DiGi\.Core\.Classes\.SerializableObject](https://learn.microsoft.com/en-us/dotnet/api/digi.core.classes.serializableobject 'DiGi\.Core\.Classes\.SerializableObject') → [DiGi\.Core\.Classes\.ConfigurationFile](https://learn.microsoft.com/en-us/dotnet/api/digi.core.classes.configurationfile 'DiGi\.Core\.Classes\.ConfigurationFile') → MaintenanceConfigurationFile
### Constructors

<a name='DiGi.Maintenance.Classes.MaintenanceConfigurationFile.MaintenanceConfigurationFile(DiGi.Core.Classes.ConfigurationFile)'></a>

## MaintenanceConfigurationFile\(ConfigurationFile\) Constructor

Initializes a new instance of the [MaintenanceConfigurationFile](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.MaintenanceConfigurationFile 'DiGi\.Maintenance\.Classes\.MaintenanceConfigurationFile') class copying settings from the source configuration file\.

```csharp
public MaintenanceConfigurationFile(DiGi.Core.Classes.ConfigurationFile? configurationFile);
```
#### Parameters

<a name='DiGi.Maintenance.Classes.MaintenanceConfigurationFile.MaintenanceConfigurationFile(DiGi.Core.Classes.ConfigurationFile).configurationFile'></a>

`configurationFile` [DiGi\.Core\.Classes\.ConfigurationFile](https://learn.microsoft.com/en-us/dotnet/api/digi.core.classes.configurationfile 'DiGi\.Core\.Classes\.ConfigurationFile')

The source configuration file to copy settings from\.

<a name='DiGi.Maintenance.Classes.MaintenanceConfigurationFile.MaintenanceConfigurationFile(System.Text.Json.Nodes.JsonObject)'></a>

## MaintenanceConfigurationFile\(JsonObject\) Constructor

Initializes a new instance of the [MaintenanceConfigurationFile](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.MaintenanceConfigurationFile 'DiGi\.Maintenance\.Classes\.MaintenanceConfigurationFile') class with the specified JSON object containing the configuration settings\.

```csharp
public MaintenanceConfigurationFile(System.Text.Json.Nodes.JsonObject? jsonObject);
```
#### Parameters

<a name='DiGi.Maintenance.Classes.MaintenanceConfigurationFile.MaintenanceConfigurationFile(System.Text.Json.Nodes.JsonObject).jsonObject'></a>

`jsonObject` [System\.Text\.Json\.Nodes\.JsonObject](https://learn.microsoft.com/en-us/dotnet/api/system.text.json.nodes.jsonobject 'System\.Text\.Json\.Nodes\.JsonObject')

The JSON object containing the configuration settings\.

<a name='DiGi.Maintenance.Classes.Solution'></a>

## Solution Class

Represents a software solution, tracking its location on disk and its version information\.

```csharp
public class Solution
```

Inheritance [System\.Object](https://learn.microsoft.com/en-us/dotnet/api/system.object 'System\.Object') → Solution
### Constructors

<a name='DiGi.Maintenance.Classes.Solution.Solution(string,System.Version)'></a>

## Solution\(string, Version\) Constructor

Initializes a new instance of the [Solution](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.Solution 'DiGi\.Maintenance\.Classes\.Solution') class\.

```csharp
public Solution(string? path, System.Version? version);
```
#### Parameters

<a name='DiGi.Maintenance.Classes.Solution.Solution(string,System.Version).path'></a>

`path` [System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')

The file system path to the solution file\.

<a name='DiGi.Maintenance.Classes.Solution.Solution(string,System.Version).version'></a>

`version` [System\.Version](https://learn.microsoft.com/en-us/dotnet/api/system.version 'System\.Version')

The version associated with the solution\.
### Properties

<a name='DiGi.Maintenance.Classes.Solution.Path'></a>

## Solution\.Path Property

Gets the file system path to the solution file\.

```csharp
public string? Path { get; }
```

#### Property Value
[System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')

<a name='DiGi.Maintenance.Classes.Solution.Version'></a>

## Solution\.Version Property

Gets or sets the version of the solution\.

```csharp
public System.Version? Version { get; set; }
```

#### Property Value
[System\.Version](https://learn.microsoft.com/en-us/dotnet/api/system.version 'System\.Version')
### Methods

<a name='DiGi.Maintenance.Classes.Solution.GetDirectory()'></a>

## Solution\.GetDirectory\(\) Method

Retrieves the directory path containing the solution file\.

```csharp
public string? GetDirectory();
```

#### Returns
[System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')  
The directory path if the [Path](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.Solution.Path 'DiGi\.Maintenance\.Classes\.Solution\.Path') is not null or whitespace; otherwise, `null`\.

<a name='DiGi.Maintenance.Classes.Solution.GetName()'></a>

## Solution\.GetName\(\) Method

Retrieves the filename of the solution without its extension\.

```csharp
public string? GetName();
```

#### Returns
[System\.String](https://learn.microsoft.com/en-us/dotnet/api/system.string 'System\.String')  
The name of the solution file if the [Path](DiGi.Maintenance.Classes.md#DiGi.Maintenance.Classes.Solution.Path 'DiGi\.Maintenance\.Classes\.Solution\.Path') is not null or whitespace; otherwise, `null`\.